#!/bin/bash
set -e

echo "This is install_ckan.sh"

echo "Installing the packages that CKAN requires..."
sudo apt-get update -qq
sudo apt-get install solr-jetty

echo "Installing CKAN and its Python dependencies..."
git clone https://github.com/ckan/ckan
cd ckan
if [ $CKANVERSION == 'master' ]
then
    echo "CKAN version: master"
else
    CKAN_TAG=$(git tag | grep ^ckan-$CKANVERSION | sort --version-sort | tail -n 1)
    git checkout $CKAN_TAG
    echo "CKAN version: ${CKAN_TAG#ckan-}"
fi

# install the recommended version of setuptools
if [ -f requirement-setuptools.txt ]
then
    echo "Updating setuptools..."
    sudo pip install -r requirement-setuptools.txt
fi

sudo python setup.py develop

sudo pip install -r requirements.txt
cd -

echo "Setting up Solr..."
printf "NO_START=0\nJETTY_HOST=127.0.0.1\nJETTY_PORT=8983\nJAVA_HOME=$JAVA_HOME" | sudo tee /etc/default/jetty
sudo cp ci/ckan/schema.xml /etc/solr/conf/schema.xml
sudo service jetty restart

echo "Creating the PostgreSQL user and database..."
sudo -u postgres psql -c "CREATE USER ckan_default WITH PASSWORD 'pass';"
sudo -u postgres psql -c 'CREATE DATABASE ckan_test WITH OWNER ckan_default;'
sudo -u postgres psql -c "CREATE USER datastore_read WITH PASSWORD 'pass' NOSUPERUSER NOCREATEDB NOCREATEROLE;"
sudo -u postgres psql -c "CREATE USER datastore_write WITH PASSWORD 'pass' NOSUPERUSER NOCREATEDB NOCREATEROLE;"
sudo -u postgres psql -c 'CREATE DATABASE datastore_test WITH OWNER ckan_default;'

echo "Initialising the database..."
paster --plugin=ckan db init -c ci/ckan/test-core.ini
paster --plugin=ckanext-datastore datastore set-permissions -c ci/ckan/test-core.ini | sudo -u postgres psql

paster serve ci/ckan/test-core.ini

sleep 5

curl http://localhost


echo "travis-build.bash is done."
