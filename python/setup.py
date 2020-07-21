from setuptools import setup, find_packages

setup(name='pyRemembeR',
      version='0.2.0',
      description='A simple utility for data scientists to save intermediate objects from either R or python.',
      utl='http://github.com/groceryheist/pyRemembeR',
      author='Nate TeBlunthuis',
      author_email='nathante@uw.edu',
      license='GPL3',
      packages=find_packages(),
      install_requires=[
          'rpy2>=3.0.4',
          'filelock>=3.0.12',
          'feather-format>=0.4.0'
      ],
      zip_safe=False)

