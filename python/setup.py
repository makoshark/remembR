from setuptools import setup

setup(name='pyRemembeR',
      version='0.1.2',
      description='A simple utility for data scientists to save intermediate objects from either R or python.',
      utl='http://github.com/groceryheist/pyRemembeR',
      author='Nate TeBlunthuis',
      author_email='nathante@uw.edu',
      license='GPL3',
      packages=['pyRemembeR'],
      install_requires=[
          'rpy2>=3.04',
      ],
      zip_safe=False)

