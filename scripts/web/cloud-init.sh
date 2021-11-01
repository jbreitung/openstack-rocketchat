#!/bin/bash
apt-get update
apt-get -y install apache2
rm /var/www/html/index.html
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
  <body>
    <h1>Greetings from my Cloud-Init :-)</h1>
    <p>hostname</p>
  </body>
</html>
EOF
sed -i "s/hostname/$HOSTNAME/" /var/www/html/index.html
sed -i "1s/$/ $HOSTNAME/" /etc/hosts