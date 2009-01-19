#!/bin/bash
#
# USAGE
# osx-app [-s] [-py /path/to/python/modules] [-l /path/to/libraries] -b /path/to/bin/algoscore -p /path/to/Info.plist
#
# This script attempts to build an AlgoScore.app package for OS X, resolving
# dynamic libraries, etc.	 
# It strips the executable and libraries if '-s' is given.
# It adds python modules if the '-py option' is given
#
# AUTHORS
#		 Kees Cook <kees@outflux.net>
#		 Michael Wybrow <mjwybrow@users.sourceforge.net>
#		 Jean-Olivier Irisson <jo.irisson@gmail.com>
# 
# Copyright (C) 2005 Kees Cook
# Copyright (C) 2005-2007 Michael Wybrow
# Copyright (C) 2007 Jean-Olivier Irisson
#
# Modifications for AlgoScore by Jonatan Liljedahl 2008
#
# Released under GNU GPL, read the file 'COPYING' for more information
#
# Thanks to GNUnet's "build_app" script for help with library dep resolution.
#		https://gnunet.org/svn/GNUnet/contrib/OSX/build_app

# Defaults
strip=false
add_python=false
python_dir=""

LIBPREFIX="/opt/local"
CPATH="$LIBPREFIX/include"
CPPFLAGS="-I$LIBPREFIX/include"
LDFLAGS="-L$LIBPREFIX/lib"
CFLAGS="-O2 -Wall"
CXXFLAGS="$CFLAGS"

# If LIBPREFIX is not already set (by osx-build.sh for example) set it to blank (one should use the command line argument to set it correctly)
if [ -z $LIBPREFIX ]; then
	LIBPREFIX=""
fi


# Help message
#----------------------------------------------------------
help()
{
echo -e "
Create an app bundle for OS X

\033[1mUSAGE\033[0m
	$0 [-s] [-py /path/to/python/modules] [-l /path/to/libraries] -b /path/to/bin/algoscore -p /path/to/Info.plist

\033[1mOPTIONS\033[0m
	\033[1m-h,--help\033[0m 
		display this help message
	\033[1m-s\033[0m
		strip the libraries and executables from debugging symbols
	\033[1m-py,--with-python\033[0m
		add python modules (numpy, lxml) from given directory
		inside the app bundle
	\033[1m-l,--libraries\033[0m
		specify the path to the library dependencies on
		(typically /sw or /opt/local)
	\033[1m-b--binary\033[0m
		specify the path to binary. By default it is in
		Build/bin/ at the base of the source code directory
	\033[1m-p,--plist\033[0m
		specify the path to Info.plist. Info.plist can be found
		in the base directory of the source code once configure
		has been run

\033[1mEXAMPLE\033[0m
	$0 -s -py ~/python-modules -l /opt/local -b ../../Build/bin/algoscore -p ../../Info.plist
"
}


# Parse command line arguments
#----------------------------------------------------------
while [ "$1" != "" ]
do
	case $1 in
		-py|--with-python)
			add_python=true
			python_dir="$2"
			shift 1 ;;
		-s)
			strip=true ;;
		-l|--libraries)
			LIBPREFIX="$2"
			shift 1 ;;
		-b|--binary)
			binary="$2"
			shift 1 ;;
		-p|--plist)
			plist="$2"
			shift 1 ;;
		-h|--help)
			help
			exit 0 ;;
		*)
			echo "Invalid command line option: $1" 
			exit 2 ;;
	esac
	shift 1
done

echo -e "\n\033[1mCREATE APP BUNDLE\033[0m\n"

# Safety tests
if [ ${add_python} = "true" ]; then
	if [ ! -e "$python_dir" ]; then
		echo "Cannot find the directory containing python modules: $python_dir" >&2
		exit 1
	fi
fi

if [ ! -e "$LIBPREFIX" ]; then
	echo "Cannot find the directory containing the libraires: $LIBPREFIX" >&2
	exit 1
fi

if [ ! -f "$binary" ]; then
	echo "Need binary" >&2
	exit 1
fi

if [ ! -f "$plist" ]; then
	echo "Need plist file" >&2
	exit 1
fi

if [ ! -x "$binary" ]; then
	echo "Not executable: $binary" >&2
	exit 1
fi


# Handle some version specific details.
#VERSION=`/usr/bin/sw_vers | grep ProductVersion | cut -f2 -d'.'`
#if [ "$VERSION" -ge "4" ]; then
	# We're on Tiger (10.4) or later.
	# XCode behaves a little differently in Tiger and later.
#	XCODEFLAGS="-configuration Deployment"
#	SCRIPTEXECDIR="ScriptExec/build/Deployment/ScriptExec.app/Contents/MacOS"
#	EXTRALIBS=""
#else
	# Panther (10.3) or earlier.
#	XCODEFLAGS="-buildstyle Deployment"
#	SCRIPTEXECDIR="ScriptExec/build/ScriptExec.app/Contents/MacOS"
#	EXTRALIBS=""
#fi


# Package always has the same name. Version information is stored in
# the Info.plist file which is filled in by the configure script.
package="AlgoScore.app"

# Remove a previously existing package if necessary
if [ -d $package ]; then
	echo "Removing previous app"
	rm -Rf $package
fi


# Set the 'macosx' directory, usually the current directory.
resdir=`pwd`


# Prepare Package
#----------------------------------------------------------
pkgexec="$package/Contents/MacOS"
pkgbin="$package/Contents/Resources/bin"
pkglib="$package/Contents/Resources/lib"
pkglocale="$package/Contents/Resources/locale"
pkgpython="$package/Contents/Resources/python/site-packages/"

mkdir -p "$pkgexec"
mkdir -p "$pkgbin"
mkdir -p "$pkglib"
mkdir -p "$pkglocale"
mkdir -p "$pkgpython"


# Build and add the launcher
#----------------------------------------------------------
#(
	# Build fails if CC happens to be set (to anything other than CompileC)
#	unset CC
	
#	cd "$resdir/ScriptExec"
#	echo -e "\033[1mBuilding launcher...\033[0m\n"
#	xcodebuild $XCODEFLAGS clean build
#)
#cp "$resdir/$SCRIPTEXECDIR/ScriptExec" "$pkgexec/AlgoScore"
cp "$resdir/AlgoScore" "$pkgexec"

# Copy all files into the bundle
#----------------------------------------------------------
echo -e "\n\033[1mFilling app bundle...\033[0m\n"

binary_name=`basename "$binary"`
binary_dir=`dirname "$binary"`

# binary
binpath="$pkgbin/algoscore-bin"
cp -v "$binary" "$binpath"
# TODO Add a "$verbose" variable and command line switch, which sets wether these commands are verbose or not

cp "$binary_dir/as_icon.png" "$pkgbin"

# Share files
#rsync -av "$binary_dir/../share/$binary_name"/* "$package/Contents/Resources/"
#rsync -av "$binary_dir/../share/$binary_name"/* "$package/Contents/Resources/"
cp "$plist" "$package/Contents/Info.plist"
rsync -av "$binary_dir/lib/" "$package/Contents/Resources/bin/lib/"
rsync -av "$binary_dir/classes/" "$package/Contents/Resources/bin/classes/"
rsync -av "$binary_dir/Help/" "$package/Contents/Resources/bin/Help/"
rsync -av "$binary_dir/examples/" "$package/Contents/Resources/bin/examples/"
# rsync -av "$binary_dir/../share/locale"/* "$package/Contents/Resources/locale"

# Icons and the rest of the script framework
rsync -av --exclude ".svn" "$resdir"/Resources/ "$package"/Contents/Resources/

# PkgInfo must match bundle type and creator code from Info.plist
echo "APPLalsc" > $package/Contents/PkgInfo

# Pull in extra requirements for Pango and GTK
pkgetc="$package/Contents/Resources/etc"
mkdir -p $pkgetc/pango
cp $LIBPREFIX/etc/pango/pangox.aliases $pkgetc/pango/
# Need to adjust path and quote in case of spaces in path.
sed -e "s,$LIBPREFIX,\"\${CWD},g" -e 's,\.so ,.so" ,g' $LIBPREFIX/etc/pango/pango.modules > $pkgetc/pango/pango.modules
cat > $pkgetc/pango/pangorc <<END_PANGO
[Pango]
ModuleFiles=\${HOME}/.algoscore-etc/pango.modules
[PangoX]
AliasFiles=\${HOME}/.algoscore-etc/pangox.aliases
END_PANGO

# We use a modified fonts.conf file so only need the dtd
mkdir -p $pkgetc/fonts
cp $LIBPREFIX/etc/fonts/fonts.dtd $pkgetc/fonts/
cp -r $LIBPREFIX/etc/fonts/conf.avail $pkgetc/fonts/
cp -r $LIBPREFIX/etc/fonts/conf.d $pkgetc/fonts/

mkdir -p $pkgetc/gtk-2.0
sed -e "s,$LIBPREFIX,\${CWD},g" $LIBPREFIX/etc/gtk-2.0/gdk-pixbuf.loaders > $pkgetc/gtk-2.0/gdk-pixbuf.loaders
sed -e "s,$LIBPREFIX,\${CWD},g" $LIBPREFIX/etc/gtk-2.0/gtk.immodules > $pkgetc/gtk-2.0/gtk.immodules

#for item in gnome-vfs-mime-magic gnome-vfs-2.0
#do
#	cp -r $LIBPREFIX/etc/$item $pkgetc/
#done

pango_version=`pkg-config --variable=pango_module_version pango`
mkdir -p $pkglib/pango/$pango_version/modules
cp $LIBPREFIX/lib/pango/$pango_version/modules/*.so $pkglib/pango/$pango_version/modules/

gtk_version=`pkg-config --variable=gtk_binary_version gtk+-2.0`
mkdir -p $pkglib/gtk-2.0/$gtk_version/{engines,immodules,loaders}
cp -r $LIBPREFIX/lib/gtk-2.0/$gtk_version/* $pkglib/gtk-2.0/$gtk_version/

#mkdir -p $pkglib/gnome-vfs-2.0/modules
#cp $LIBPREFIX/lib/gnome-vfs-2.0/modules/*.so $pkglib/gnome-vfs-2.0/modules/

# Find out libs we need from fink, darwinports, or from a custom install
# (i.e. $LIBPREFIX), then loop until no changes.
a=1
nfiles=0
endl=true
while $endl; do
	echo -e "\033[1mLooking for dependencies.\033[0m Round" $a
	libs="`otool -L $pkglib/gtk-2.0/$gtk_version/loaders/* $pkglib/gtk-2.0/$gtk_version/immodules/* $pkglib/gtk-2.0/$gtk_version/engines/*.so $pkglib/pango/$pango_version/modules/* $pkglib/gnome-vfs-2.0/modules/* $package/Contents/Resources/lib/* $binary 2>/dev/null | fgrep compatibility | cut -d\( -f1 | grep $LIBPREFIX | sort | uniq`"
	cp -f $libs $package/Contents/Resources/lib
	let "a+=1"	
	nnfiles=`ls $package/Contents/Resources/lib | wc -l`
	if [ $nnfiles = $nfiles ]; then
		endl=false
	else
		nfiles=$nnfiles
	fi
done

# Add extra libraries of necessary
for libfile in $EXTRALIBS
do
	cp -f $libfile $package/Contents/Resources/lib
done


# Strip libraries and executables if requested
#----------------------------------------------------------
if [ "$strip" = "true" ]; then
	echo -e "\n\033[1mStripping debugging symbols...\033[0m\n"
	chmod +w "$pkglib"/*.dylib
	strip -x "$pkglib"/*.dylib
	strip -ur "$binpath"
fi

# NOTE: This works for all the dylibs but causes GTK to crash at startup.
#				Instead we leave them with their original install_names and set
#				DYLD_LIBRARY_PATH within the app bundle before running Inkscape.
#
# fixlib () {
#		# Fix a given executable or library to be relocatable
#		if [ ! -d "$1" ]; then
#			echo $1
#			libs="`otool -L $1 | fgrep compatibility | cut -d\( -f1`"
#			for lib in $libs; do
#				echo "	$lib"
#				base=`echo $lib | awk -F/ '{print $NF}'`
#				first=`echo $lib | cut -d/ -f1-3`
#				to=@executable_path/../lib/$base
#				if [ $first != /usr/lib -a $first != /usr/X11R6 ]; then
#					/usr/bin/install_name_tool -change $lib $to $1
#					if [ "`echo $lib | fgrep libcrypto`" = "" ]; then
#						/usr/bin/install_name_tool -id $to ../lib/$base
#						for ll in $libs; do
#							base=`echo $ll | awk -F/ '{print $NF}'`
#							first=`echo $ll | cut -d/ -f1-3`
#							to=@executable_path/../lib/$base
#							if [ $first != /usr/lib -a $first != /usr/X11R6 -a "`echo $ll | fgrep libcrypto`" = "" ]; then
#								/usr/bin/install_name_tool -change $ll $to ../lib/$base
#							fi
#						done
#					fi
#				fi
#			done
#		fi
# }
# 
# Fix package deps
#(cd "$package/Contents/MacOS/bin"
# for file in *; do
#		 fixlib "$file"
# done
# cd ../lib
# for file in *; do
#		 fixlib "$file"
# done)

exit 0
