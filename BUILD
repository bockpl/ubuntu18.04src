if [ $1 ]
then
	VERSION=$1
	echo $VERSION > ./VERSION
fi

if [ -f ./VERSION ]
then
	./makeTemplate $(cat ./VERSION)
fi

