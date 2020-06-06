#!/bin/bash
if [ "$1" == "production" ]; then
  BUILD_ENV=production
  OPTS='--optimize-minimize'
else
  BUILD_ENV=development
fi

rm -rf priv/static
(cd assets && \
node_modules/webpack/bin/webpack.js --mode $BUILD_ENV $OPTS )
