# Setup file for package datawire_mdk

from setuptools import setup, find_packages
from os import path
from glob import glob

here = path.abspath(path.dirname(__file__))
with open(path.join(here, 'README.rst'), encoding='utf-8') as f:
    long_description = f.read()


setup(name="datawire_mdk",
      version='2.0.37',
      install_requires=["wheel", "ws4py==0.3.4", "future==0.15.2",
                        # Technically only need this for Flask users, but it's
                        # nicer experience if you don't have to tell users 'and
                        # install datawire-mdk[flask]. Maybe we want separate
                        # Python package for Flask support?
                        "blinker==1.4",
      ],
      setup_requires=["wheel"],
      py_modules=[path.splitext(i)[0] for i in glob("*.py") if i != "setup.py"],
      packages=find_packages(),
      license='Apache-2.0',
      url='https://www.datawire.io',
      author='Datawire.io',
      description='The Microservices Development Kit (MDK)',
      long_description=long_description)
