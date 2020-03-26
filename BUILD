if [ $1 ]
then
	VERSION=$1
	echo $VERSION > ./VERSION
fi

if [ -f ./VERSION ]
then
	./set_configs_permissions.sh
	./makeTemplate $(cat ./VERSION)
fi
