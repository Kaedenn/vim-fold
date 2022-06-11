
# Section {{{0

# Section {{{1

def func(arg, kwarg=1):
  pass

# 1}}}

def func2(arg):
  return arg

# 0}}}

def decorate(func):
  def wrapper(*args, **kwargs):
    print("{}({*}, **{})".format(func, args, kwargs))
    return func(*args, **kwargs)
  return wrapper

def build_decorator(name):
  def decorator(func):
    def wrapper(*args, **kwargs):
      print("{}(*{}, **{})".format(name, args, kwargs))
      return func(*args, **kwargs)
    return wrapper
  return decorator

@decorate
def baz():
  pass

@build_decorator("foo")
def foo():
  pass

@build_decorator("bar")
def bar(arg, kwarg=1):
  pass

def build_decorator_2(name):
  def decorator(func):
    def wrapper(*args, **kwargs):
      print("{}({}, {})".format(name, args, kwargs))
      return func(*args, **kwargs)
    return wrapper
  return decorator

@build_decorator_2("baz")
@build_decorator("nested")
def nested():
  pass

def regular(args):
  return args

class Foo:
  def __init__(self):
    pass

  @property
  def name(self):
    return "Foo"

  def get_name(self):
    return self.name

class Bar(object):
  def __init__(self):
    pass

  @property
  def name(self):
    return "Bar"

  def get_name(self):
    return self.name

# vim-fold-opt: debug
