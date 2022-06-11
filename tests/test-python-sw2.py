#!/usr/bin/env python3

"""

"""

import argparse
import logging
import os
import sys

logging.basicConfig(format="%(module)s:%(lineno)s: %(levelname)s: %(message)s",
                    level=logging.INFO)
logger = logging.getLogger(__name__)

def foo(func):
  logger.debug(func)
  return func

def foo_wrap(name):
  def decorator(func):
    def wrapper_func(*a, **kw):
      logger.info("wrapped for %s(%s, %s)", name, a, kw)
    return wrapper_func
  return decorator

@foo
def bar(*a, **kw):
  logger.info("bar(%s, %s)", a, kw)

@foo_wrap
def baz(*a, **kw):
  logger.info("Called bar(%s, %s)", a, kw)

def main():
  ap = argparse.ArgumentParser()
  ap.add_argument("-v", "--verbose", action="store_true", help="verbose output")
  args = ap.parse_args()
  if args.verbose:
    logger.setLevel(logging.DEBUG)

  bar()

if __name__ == "__main__":
  main()

# vim: set ts=2 sts=2 sw=2:
