from distutils.core import setup

setup(
    name='Flask-Lightroom',
    version='0.0.1',
    description='Adobe Photoshop Lightroom integration with Flask.',
    url='http://github.com/mikeboers/Flask-Lightroom',
    
    pymodules=['flask_lightroom'],
    
    author='Mike Boers',
    author_email='flask-lightroom@mikeboers.com',
    license='BSD-3',

    install_requires='''
        Flask
    ''',  
)
