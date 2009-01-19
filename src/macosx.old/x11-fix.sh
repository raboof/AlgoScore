#!/bin/sh
cd /Applications/Utilities/X11.app/Contents/MacOS

if test -f X11-bin
then
  echo "X11-bin exists. This script has already been run?"
  exit 1
fi

sudo mv -v X11 X11-bin

if test -f X11
then
  echo "X11 exists. Will not overwrite. Aborting..."
  exit 1
fi

rm -v ~/.Xmodmap

echo Creating X11 wrapper script...
sudo cat > X11 << EOF
#!/bin/sh
cd \$(dirname "\$0")
./X11-bin +kb "\$@"
EOF
sudo chmod +x X11
echo Done. Please restart your X11.
exit 0
