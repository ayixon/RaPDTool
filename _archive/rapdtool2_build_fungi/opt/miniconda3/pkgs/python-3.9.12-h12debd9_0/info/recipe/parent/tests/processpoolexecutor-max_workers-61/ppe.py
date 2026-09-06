import concurrent.futures
import math

PRIMES = [
    112272535095293,
    112582705942171,
    112272535095293,
    115280095190773,
    115797848077099,
    1099726899285419]

def is_prime(n):
    if n < 2:
        return False
    if n == 2:
        return True
    if n % 2 == 0:
        return False

    sqrt_n = int(math.floor(math.sqrt(n)))
    for i in range(3, sqrt_n + 1, 2):
        if n % i == 0:
            return False
    return True

def main():
    #
    # max_workers=None is fine (on a low-end machine), max_workers=60 is fine, max_workers=61 results in:
    # 
    # Exception in thread QueueManagerThread:
    # Traceback (most recent call last):
    #   File "C:\opt\conda\conda-bld\python-dbg-3.8.2-win-64\work\lib\threading.py", line 932, in _bootstrap_inner
    #     self.run()
    #   File "C:\opt\conda\conda-bld\python-dbg-3.8.2-win-64\work\lib\threading.py", line 870, in run
    #     self._target(*self._args, **self._kwargs)
    #   File "C:\opt\conda\conda-bld\python-dbg-3.8.2-win-64\work\lib\concurrent\futures\process.py", line 362, in _queue_management_worker
    #     ready = mp.connection.wait(readers + worker_sentinels)
    #   File "C:\opt\conda\conda-bld\python-dbg-3.8.2-win-64\work\lib\multiprocessing\connection.py", line 878, in wait
    #     ready_handles = _exhaustive_wait(waithandle_to_obj.keys(), timeout)
    #   File "C:\opt\conda\conda-bld\python-dbg-3.8.2-win-64\work\lib\multiprocessing\connection.py", line 810, in _exhaustive_wait
    #     res = _winapi.WaitForMultipleObjects(L, False, timeout)
    # ValueError: need at most 63 handles, got a sequence of length 63
    #
    # max_workers=62 results in:
    #
    # Traceback (most recent call last):
    #   File "C:\opt\r\a\python-feedstock\recipe\tests\ppi.py", line 48, in <module>
    #     main()
    #   File "C:\opt\r\a\python-feedstock\recipe\tests\ppi.py", line 43, in main
    #     with concurrent.futures.ProcessPoolExecutor(max_workers=62) as executor:
    #   File "C:\opt\conda\conda-bld\python-dbg-3.8.2-win-64\work\lib\concurrent\futures\process.py", line 523, in __init__
    #     raise ValueError(
    # ValueError: max_workers must be <= 61
    # 
    with concurrent.futures.ProcessPoolExecutor(max_workers=61) as executor:
        for number, prime in zip(PRIMES, executor.map(is_prime, PRIMES)):
            print('%d is prime: %s' % (number, prime))

if __name__ == '__main__':
    main()

