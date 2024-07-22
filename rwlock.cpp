#include <fcntl.h>
#include <semaphore.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#include <cstring>
#include <iostream>
#include <semaphore.h>
#include <stdexcept>
#include <string>

/*
https://docs.python.org/3/library/multiprocessing.html
Python multiprocessing.shared_memory.SharedMemory is named. However multiprocessing.Lock is anonymous.
This means that multiple unrelated processes cannot hold the same Lock object.

man pthread_rwlock_unlock(3p)
The pthread_rwlock_unlock() function shall release a lock held on the read‐write lock object referenced by rwlock.
Results are undefined if the read‐write lock rwlock is not held by the calling thread.

This C program implements RWLock based on POSIX named semaphore and named shared memory.

The container use separated IPC namespace by default. Pass `--ipc=host` at container creation if you need rwlock between containers.
*/

class NamedMutex {
public:
    NamedMutex(const std::string &sem_name, unsigned int value = 1, bool unlink_at_destructor = false)
        : sem_name_(sem_name), unlink_at_destructor_(unlink_at_destructor) {
        sem_ = sem_open(sem_name.c_str(), O_CREAT, 0666, value);
        if (sem_ == nullptr) {
            perror("sem_open");
            throw std::runtime_error("sem_open failed");
        }
    }

    ~NamedMutex() {
        if (sem_ != nullptr) {
            sem_close(sem_);
            if (unlink_at_destructor_)
                sem_unlink(sem_name_.c_str());
        }
    }

    void Lock() {
        if (sem_wait(sem_) == -1) {
            perror("sem_wait");
            throw std::runtime_error("sem_wait failed");
        }
    }

    void Unlock() {
        if (sem_post(sem_) == -1) {
            perror("sem_post");
            throw std::runtime_error("sem_post failed");
        }
    }

private:
    sem_t *sem_;
    std::string sem_name_;
    bool unlink_at_destructor_;
};

struct shmbuf {
    size_t readers_; /* Number of readers */
    size_t writers_; /* Number of writers */
};

class NamedMutexGuard {
public:
    NamedMutexGuard(NamedMutex &mtx) : mtx_(mtx) { mtx_.Lock(); }

    ~NamedMutexGuard() { mtx_.Unlock(); }

private:
    NamedMutex &mtx_;
};

class NamedRWLock {
public:
    NamedRWLock(const std::string &sem_name, bool unlink_at_destructor = false)
        : unlink_at_destructor_(unlink_at_destructor), mtx_(sem_name, 1, unlink_at_destructor) {
        NamedMutexGuard guard(mtx_);

        /* Create shared memory object and set its size to the size
        of our structure. */
        int fd = shm_open(sem_name.c_str(), O_CREAT | O_RDWR, 0666);
        if (fd == -1) {
            throw std::runtime_error("shm_open failed");
        }
        struct stat sem_stat;
        if (fstat(fd, &sem_stat) == -1) {
            throw std::runtime_error("fstat failed");
        }
        bool need_init = sem_stat.st_size != sizeof(struct shmbuf);
        if (need_init) {
            if (ftruncate(fd, sizeof(struct shmbuf)) == -1) {
                throw std::runtime_error("ftruncate failed");
            }
        }

        /* Map the object into the caller's address space. */
        void *shmp = mmap(NULL, sizeof(struct shmbuf), PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
        if (shmp == MAP_FAILED) {
            throw std::runtime_error("mmap failed");
        }
        close(fd);
        shm_ = (struct shmbuf *)shmp;
        if (need_init) {
            memset(shm_, 0, sizeof(struct shmbuf));
        }
    }

    ~NamedRWLock() {}

    int RLock() {
        while (1) {
            mtx_.Lock();
            if (shm_->writers_ == 0)
                break;
            mtx_.Unlock();
            usleep(1000000);
        }
        shm_->readers_++;
        mtx_.Unlock();
        return 0;
    }
    int RUnlock() {
        NamedMutexGuard guard(mtx_);
        if (shm_->writers_ != 0 || shm_->readers_ <= 0)
            return -1;
        shm_->readers_--;
        return 0;
    }

    int WLock() {
        while (1) {
            mtx_.Lock();
            if (shm_->readers_ + shm_->writers_ == 0)
                break;
            mtx_.Unlock();
            usleep(1000000);
        }
        shm_->writers_++;
        mtx_.Unlock();
        return 0;
    }
    int WUnlock() {
        NamedMutexGuard guard(mtx_);
        if (shm_->readers_ != 0 || shm_->writers_ != 1)
            return -1;
        shm_->writers_--;
        return 0;
    }
    int Stat() {
        NamedMutexGuard guard(mtx_);
        std::cout << "readers: " << shm_->readers_ << ", writers: " << shm_->writers_ << std::endl;
        return 0;
    }

private:
    bool unlink_at_destructor_;
    NamedMutex mtx_;
    shmbuf *shm_;
};

// sem_name, operation(rlock, runlock, wlock, wunlock)
int main(int argc, char *argv[]) {
    if (argc != 3) {
        std::cout << "Usage: " << argv[0] << " <sem_name> <operation>" << std::endl;
        return 1;
    }
    int rc = 0;
    NamedRWLock rwlock(argv[1]);
    if (strcmp(argv[2], "rlock") == 0) {
        rc = rwlock.RLock();
    } else if (strcmp(argv[2], "runlock") == 0) {
        rc = rwlock.RUnlock();
    } else if (strcmp(argv[2], "wlock") == 0) {
        rc = rwlock.WLock();
    } else if (strcmp(argv[2], "wunlock") == 0) {
        rc = rwlock.WUnlock();
    } else if (strcmp(argv[2], "stat") == 0) {
        rc = rwlock.Stat();
    } else {
        std::cout << "Usage: " << argv[0] << " <sem_name> <operation>" << std::endl;
        return -1;
    }
    return rc;
}