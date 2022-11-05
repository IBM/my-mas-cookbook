#!/bin/bash
set -e
cat <<\EOF > test.sh
#!/bin/bash
echo hello
EOF
chmod +x ./test.sh
exit 0
