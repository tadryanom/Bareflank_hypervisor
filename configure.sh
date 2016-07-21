#!/bin/bash -e
#
# Bareflank Hypervisor
#
# Copyright (C) 2015 Assured Information Security, Inc.
# Author: Rian Quinn        <quinnr@ainfosec.com>
# Author: Brendan Kerrigan  <kerriganb@ainfosec.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA

version=1

# ------------------------------------------------------------------------------
# Colors
# ------------------------------------------------------------------------------

CB='\033[1;34m'
CR='\033[1;91m'
CE='\033[0m'

# ------------------------------------------------------------------------------
# Environment
# ------------------------------------------------------------------------------

# The "-nt" only has second resolution which causes problems so this function
# provides a nanosecond resolution. It has to be broken up into two comparisons
# because putting them together makes for a number larger than 64bits.

nt() {

    if [[ ! -f $1 ]]; then
        return 1
    fi

    if [[ ! -f $2 ]]; then
        return 0
    fi

    file1_ts=`date +"%y%m%d%H%M%S" -r $1`
    file2_ts=`date +"%y%m%d%H%M%S" -r $2`

    if [[ $((10#$file1_ts)) -eq $((10#$file2_ts)) ]]; then
        file1_ts=`date +"%N" -r $1`
        file2_ts=`date +"%N" -r $2`
        if [[ $((10#$file1_ts)) -gt $((10#$file2_ts)) ]]; then
            return 0
        else
            return 1
        fi
    else
        if [[ $((10#$file1_ts)) -gt $((10#$file2_ts)) ]]; then
            return 0
        else
            return 1
        fi
    fi
}

# ------------------------------------------------------------------------------
# Environment
# ------------------------------------------------------------------------------

# We still need to do version change detection when a "-u" is being done, and
# fix things

# It's also not detecting when a makefile has changed

check_version() {
    if [[ -f "$BUILD_ABS/configure_version" ]]; then
        current_version=`cat $BUILD_ABS/configure_version`
    else
        return 0
    fi

    if [[ $((version)) -lt $((current_version)) ]]; then
        warn_version_change="true"
    fi

    if [[ $((version)) -ne $((current_version)) ]]; then
        version_change="true"
    fi
}

check_env() {
    if [[ ! -f "$BUILD_ABS/env.sh" ]]; then
        echo -e "creating script:$CB env.sh$CE"
        echo "export BUILD_ABS=\"$BUILD_ABS\"" >> $BUILD_ABS/env.sh
        echo "export HYPER_ABS=\"$HYPER_ABS\"" >> $BUILD_ABS/env.sh
        echo "export LLVM_RELEASE=\"release_38\"" >> $BUILD_ABS/env.sh
        echo "export module_file=\"$module_file\"" >> $BUILD_ABS/env.sh
        echo "export compiler=\"$compiler\"" >> $BUILD_ABS/env.sh
        printf "export extensions=\"" >> $BUILD_ABS/env.sh
        printf "%s;" "${extensions[@]}" >> $BUILD_ABS/env.sh
        printf "\"\n" >> $BUILD_ABS/env.sh
    fi

    echo "$version" > $BUILD_ABS/configure_version
}

check_git_working_tree() {
    if [[ ! -f "$BUILD_ABS/git_working_tree.sh" ]]; then
        echo -e "creating script:$CB git_working_tree.sh$CE"
        echo "export GIT_DIR=\"$HYPER_ABS/.git\"" >> $BUILD_ABS/git_working_tree.sh
        echo "export GIT_WORK_TREE=\"$HYPER_ABS\"" >> $BUILD_ABS/git_working_tree.sh
    fi
}

setup_environment_variables() {

    local dirname=`dirname $0`

    BUILD_ABS=`pwd`;
    BUILD_REL=`pwd`;
    HYPER_ABS=`cd "$dirname"; pwd`;
    HYPER_REL=`cd "$dirname"; pwd`;

    if [[ -z "$module_file" ]]; then
        module_file=$HYPER_ABS/bfm/bin/native/vmm.modules
    fi

    if [[ -z "$compiler" ]]; then
        compiler=gcc_520
    fi
}

# ------------------------------------------------------------------------------
# Options
# ------------------------------------------------------------------------------

option_help() {
    echo -e "Usage: configure [OPTION]"
    echo -e "Configures the Bareflank out-of-tree build environment"
    echo -e ""
    echo -e "       -h, --help                       show this help menu"
    echo -e "       -c, --clean                      remove build components"
    echo -e "       -u, --update_all                 updates all files"
    echo -e "       -s, --update_scripts             updates everything minus makefiles"
    echo -e "       -r, --update_makefiles           updates makefiles only"
    echo -e "       -m, --module_file <filename>     module_file to use"
    echo -e "       -e, --extension <dirname>        directory of extension"
    echo -e "       -g, --compiler <dirname>         directory of cross compiler"
    echo -e ""
}

option_distclean() {
    if [[ -z "$BUILD_ABS" ]]; then
        echo "FATAL ERROR: BUILD_ABS not set"
        exit 1
    fi

    if [[ ! $PWD == "$BUILD_ABS"* ]]; then
        echo "ERROR: Build system has moved which is not supported!!!"
        exit 3
    fi

    if [[ -d "$BUILD_ABS/makefiles" ]]; then
        echo -e "removing:$CB makefiles$CE"
        rm -Rf $BUILD_ABS/makefiles
    fi

    if [[ -f "$BUILD_ABS/configure_version" ]] || \
       [[ -f "$BUILD_ABS/env.sh" ]] || \
       [[ -f "$BUILD_ABS/git_working_tree.sh" ]] || \
       [[ -f "$BUILD_ABS/module_file" ]] || \
       [[ -f "$BUILD_ABS/build_scripts" ]]; then
        echo -e "removing:$CB scripts$CE"
        rm -Rf $BUILD_ABS/Makefile
        rm -Rf $BUILD_ABS/configure_version
        rm -Rf $BUILD_ABS/env.sh
        rm -Rf $BUILD_ABS/git_working_tree.sh
        rm -Rf $BUILD_ABS/module_file
        rm -Rf $BUILD_ABS/build_scripts
    fi

    if [[ -d "$BUILD_ABS/build_libbfc" ]] || \
       [[ -d "$BUILD_ABS/build_libcxx" ]] || \
       [[ -d "$BUILD_ABS/build_libcxxabi" ]] || \
       [[ -d "$BUILD_ABS/build_newlib" ]]; then
        echo -e "removing:$CB build dirs$CE"
        rm -Rf $BUILD_ABS/build_libbfc
        rm -Rf $BUILD_ABS/build_libcxx
        rm -Rf $BUILD_ABS/build_libcxxabi
        rm -Rf $BUILD_ABS/build_newlib
    fi

    if [[ -d "$BUILD_ABS/source_libbfc" ]] || \
       [[ -d "$BUILD_ABS/source_libcxx" ]] || \
       [[ -d "$BUILD_ABS/source_libcxxabi" ]] || \
       [[ -d "$BUILD_ABS/source_llvm" ]] || \
       [[ -d "$BUILD_ABS/source_newlib" ]]; then
        echo -e "removing:$CB source dirs$CE"
        rm -Rf $BUILD_ABS/source_libbfc
        rm -Rf $BUILD_ABS/source_libcxx
        rm -Rf $BUILD_ABS/source_libcxxabi
        rm -Rf $BUILD_ABS/source_llvm
        rm -Rf $BUILD_ABS/source_newlib
    fi

    if [[ -d "$BUILD_ABS/sysroot" ]]; then
        echo -e "removing:$CB sysroot$CE"
        rm -Rf $BUILD_ABS/sysroot
    fi

    if [[ -d "$BUILD_ABS/extensions" ]]; then
        echo -e "removing:$CB extension links$CE"
        rm -Rf $BUILD_ABS/extensions
    fi

    rebuild_all="true"
}

option_run() {
    if [[ ! $update == "true" ]]; then
        setup_environment_variables
        rebuild_all="true"
    else
        if [[ -z "$BUILD_ABS" ]]; then
            BUILD_ABS=`pwd`
        fi
        if [[ -f "$BUILD_ABS/env.sh" ]]; then
            source $BUILD_ABS/env.sh
        else
            echo "ERROR: Unable to locate environment variables"
            exit 2
        fi
        if [[ -z "$HYPER_REL" ]]; then
            HYPER_REL=$HYPER_ABS
        fi
        if [[ -z "$BUILD_REL" ]]; then
            BUILD_REL=$BUILD_ABS
        fi
        if [[ -z "$compiler" ]]; then
            compiler=gcc_520
        fi
        IFS=';' read -ra extensions <<< "$extensions"
    fi

    if [[ ! $PWD == "$BUILD_ABS"* ]]; then
        echo "ERROR: Build system has moved which is not supported!!!"
        exit 3
    fi

    check_version

    if [[ ! $update == "true" ]] || [[ $version_change == "true" ]]; then
        cd $BUILD_ABS
        option_distclean
    fi

    if [[ $rebuild_all == "true" ]]; then
        if [[ ! -d $BUILD_ABS/makefiles ]]; then
            mkdir -p $BUILD_ABS/makefiles
        fi
        check_env
        check_git_working_tree
        create_extension_links
        recursively_copy_makefiles $BUILD_ABS/makefiles $HYPER_ABS
        recursively_copy_makefiles $BUILD_ABS/makefiles $BUILD_ABS/extensions
        create_root_makefile
        copy_scripts
        check_module_file
        create_wrapper_links
    elif [[ $rebuild_scripts == "true" ]]; then
        check_env
        check_git_working_tree
        create_extension_links
        copy_scripts
        check_module_file
        create_wrapper_links
    elif [[ $rebuild_makefiles == "true" ]]; then
        if [[ $BUILD_ABS == $PWD ]]; then
            create_root_makefile
        else
            check_makefile $BUILD_REL $HYPER_REL
        fi
    fi

    if [[ $this_is_make == "true" ]] && [[ $warn_version_change == "true" ]]; then
        echo "WARNING: The previous build system was newer than the current one."
        echo "         As a result, the current build system might be broken."
        echo "         If a problem occurs, you might have delete your build dir,"
        echo "         create a new one, and re-run configure"
    fi

    if [[ $this_is_make == "true" ]] && [[ $version_change == "true" ]]; then
        echo "Make cannot continue as a version change occured. Please re-run make!!!"
        exit 5
    fi
}

# ------------------------------------------------------------------------------
# Copy Makefiles
# ------------------------------------------------------------------------------

# Converts a line to use absolute paths instead of relative paths. This
# function tables a line in the following format
#
# var_name <delimiter> file1 %HYPER_ABS%/file2 /file3
#
# %HYPER_ABS%: the absolute (root) location of the hypervisor
# %HYPER_REL%: the relative location of Makefile.bf file being parsed
# %BUILD_ABS%: the absolute (root) location of the build tree
# %BUILD_REL%: the relative location of Makefile file being created
#
# If the file starts with %xxx%, the path is replaced and if the file starts
# with "/" it is assumed that the file already is an absolute path.
# Otherwise, the makefile's current location is added to the file so that
# it's now an absolute path instead.
#
# Note that last_line is used to remove additional whitespace that is not
# needed. Also note that there is a strange issue breaking up the variable
# when the delimiter is changed, so we have a hack in there to change the
# array indexes when needed.
#
# $1: the line to add paths to
# $2: hyper_rel path
# $4: build_rel path
# $4: file name to write to
# $5: delimiter
#
add_absolute_path() {

    last_line=

    IFS=$5 read -ra var <<< "$1"
    local var_name=${var[0]}
    local var_args=${var[1]}

    if [[ -z $var_args ]]; then
        var_args=${var[2]}
    fi

    IFS=' ' read -ra array <<< "$var_args"
    for filename in "${array[@]}"; do

        last_line="something"

        if [[ $filename == /* ]]; then
            echo $var_name$5$filename >> $4
            continue
        fi

        if [[ $filename == %HYPER_ABS%* ]]; then
            echo $var_name$5$HYPER_ABS/${filename#"%HYPER_ABS%/"} >> $4
            continue
        fi

        if [[ $filename == %BUILD_ABS%* ]]; then
            echo $var_name$5$BUILD_ABS/${filename#"%BUILD_ABS%/"} >> $4
            continue
        fi

        if [[ $filename == %HYPER_REL%* ]]; then
            echo $var_name$5$2/${filename#"%HYPER_REL%/"} >> $4
            continue
        fi

        if [[ $filename == %BUILD_REL%* ]]; then
            echo $var_name$5$3/${filename#"%BUILD_REL%/"} >> $4
            continue
        fi

        echo $var_name$5$2/$filename >> $4

    done
}

copy_makefile() {
    rm -Rf $1/Makefile.tmp

    echo -e "################################################################################" >> $1/Makefile.tmp
    echo -e "# Auto Generated Section (created by configured script)" >> $1/Makefile.tmp
    echo -e "################################################################################" >> $1/Makefile.tmp
    echo -e "" >> $1/Makefile.tmp
    echo -e "HYPER_ABS:=$HYPER_ABS" >> $1/Makefile.tmp
    echo -e "BUILD_ABS:=$BUILD_ABS" >> $1/Makefile.tmp
    echo -e "HYPER_REL:=$2" >> $1/Makefile.tmp
    echo -e "BUILD_REL:=$1" >> $1/Makefile.tmp
    echo -e "MAKEFILE_ABS:=\$(dir \$(abspath \$(lastword \$(MAKEFILE_LIST))))" >> $1/Makefile.tmp
    echo -e "ifneq (\$(dir \$(BUILD_REL)/), \$(MAKEFILE_ABS))" >> $1/Makefile.tmp
    echo -e "    \$(error Build system has moved which is not supported!!!)" >> $1/Makefile.tmp
    echo -e "endif" >> $1/Makefile.tmp
    echo -e "" >> $1/Makefile.tmp
    echo -e "" >> $1/Makefile.tmp

    while IFS='' read -r line
    do
        trimmed_line=`echo $line`

        case "$trimmed_line" in
            *SOURCES*)
                add_absolute_path "$trimmed_line" $2 $1 $1/Makefile.tmp '+='
                ;;
            *PATHS*)
                add_absolute_path "$trimmed_line" $2 $1 $1/Makefile.tmp '+='
                ;;
            *OBJDIR*)
                add_absolute_path "$trimmed_line" $2 $1 $1/Makefile.tmp '+='
                ;;
            *OUTDIR*)
                add_absolute_path "$trimmed_line" $2 $1 $1/Makefile.tmp '+='
                ;;
            include*)
                add_absolute_path "$trimmed_line" $2 $1 $1/Makefile.tmp ' '
                ;;
            *)
                if [[ -z "$trimmed_line" ]] && [[ ! -z "$last_line" ]]; then
                    echo " " >> $1/Makefile.tmp
                fi

                if [[ ! -z "$trimmed_line" ]]; then
                    if [[ $trimmed_line == *+=* ]] && [[ $trimmed_line == *+= ]]; then
                        line=
                    else
                        echo "$line" >> $1/Makefile.tmp
                    fi

                fi

                last_line="$line"
                ;;
        esac

    done < $2/Makefile.bf

    sed -i "s/%HYPER_ABS%/${HYPER_ABS//\//\\/}/g" $1/Makefile.tmp
    sed -i "s/%BUILD_ABS%/${BUILD_ABS//\//\\/}/g" $1/Makefile.tmp
    sed -i "s/%HYPER_REL%/${2//\//\\/}/g" $1/Makefile.tmp
    sed -i "s/%BUILD_REL%/${1//\//\\/}/g" $1/Makefile.tmp

    mv $1/Makefile.tmp $1/Makefile
}

check_makefile() {
    if nt "$2/Makefile.bf" "$1/Makefile"; then
        echo -e "generating makefile: $CB$1/Makefile$CE"
        copy_makefile $1 `cd $2; pwd -P`
    fi
}

recursively_copy_makefiles() {
    if [[ -f "$2/Makefile.bf" ]]; then
        check_makefile $1 $2
    fi

    if [[ -f "$2/Makefile.bf" ]] || [[ $2 == "$BUILD_ABS/extensions" ]]; then
        for dir in $2/*
        do
            if [[ ! -d "$dir" ]]; then
                continue
            fi

            local abs_dir=$dir
            local rel_dir=`basename $abs_dir`

            if [[ -f "$2/$rel_dir/Makefile.bf" ]]; then
                if [[ ! -d "$1/$rel_dir" ]]; then
                    mkdir -p $1/$rel_dir
                fi
                recursively_copy_makefiles $1/$rel_dir $2/$rel_dir
            fi

        done
    fi
}

# ------------------------------------------------------------------------------
# Copy Script
# ------------------------------------------------------------------------------

# Copy Script
#
# This copies a script from the hypervisor tree to the build tree. In doing
# do it fills in the environment script location so that the script can
# source it's environment variables.
#
# $1: the script to copy
#
copy_script() {

    local hyper_filename="$HYPER_ABS/tools/scripts/$1"
    local build_filename="$BUILD_ABS/build_scripts/$1"

    if nt "$hyper_filename" "$build_filename"; then

        echo -e "generating script: $CB$1$CE"

        if [[ ! -d $BUILD_ABS/build_scripts/ ]]; then
            mkdir -p $BUILD_ABS/build_scripts/
        fi

        cp -p $hyper_filename $build_filename
        sed -i "s/%ENV_SOURCE%/source ${BUILD_ABS//\//\\/}\/env.sh/g" $build_filename

    fi
}

copy_scripts() {
    copy_script "bareflank-gcc-wrapper.sh"
    copy_script "filter_module_file.sh"
    copy_script "build_newlib.sh"
    copy_script "build_libcxx.sh"
    copy_script "build_libcxxabi.sh"
    copy_script "build_libbfc.sh"
    copy_script "build_driver.sh"
    copy_script "clean_driver.sh"
    copy_script "fetch_newlib.sh"
    copy_script "fetch_libcxx.sh"
    copy_script "fetch_libcxxabi.sh"
    copy_script "fetch_llvm.sh"
    copy_script "fetch_libbfc.sh"
}

# ------------------------------------------------------------------------------
# Wrapper Links
# ------------------------------------------------------------------------------

create_wrapper_links () {
    if [[ ! -f "$BUILD_ABS/build_scripts/x86_64-bareflank-gcc" ]]; then
        echo -e "linking compiler script:$CB x86_64-bareflank-gcc$CE"
        ln -s $BUILD_ABS/build_scripts/bareflank-gcc-wrapper.sh $BUILD_ABS/build_scripts/x86_64-bareflank-gcc
    fi

    if [[ ! -f "$BUILD_ABS/build_scripts/x86_64-bareflank-g++" ]]; then
        echo -e "linking compiler script:$CB x86_64-bareflank-g++$CE"
        ln -s $BUILD_ABS/build_scripts/bareflank-gcc-wrapper.sh $BUILD_ABS/build_scripts/x86_64-bareflank-g++
    fi

    if [[ ! -f "$BUILD_ABS/build_scripts/x86_64-bareflank-ar" ]]; then
        echo -e "linking compiler script:$CB x86_64-bareflank-ar$CE"
        ln -s $BUILD_ABS/build_scripts/bareflank-gcc-wrapper.sh $BUILD_ABS/build_scripts/x86_64-bareflank-ar
    fi

    if [[ ! -f "$BUILD_ABS/build_scripts/x86_64-bareflank-nasm" ]]; then
        echo -e "linking compiler script:$CB x86_64-bareflank-nasm$CE"
        ln -s $BUILD_ABS/build_scripts/bareflank-gcc-wrapper.sh $BUILD_ABS/build_scripts/x86_64-bareflank-nasm
    fi

    if [[ ! -f "$BUILD_ABS/build_scripts/x86_64-bareflank-docker" ]]; then
        echo -e "linking compiler script:$CB x86_64-bareflank-docker$CE"
        ln -s $BUILD_ABS/build_scripts/bareflank-gcc-wrapper.sh $BUILD_ABS/build_scripts/x86_64-bareflank-docker
    fi
}

# ------------------------------------------------------------------------------
# Check Module Files
# ------------------------------------------------------------------------------

check_module_file () {
    if nt "$module_file" "$BUILD_ABS/module_file"; then
        echo -e "copying module file: $CB$module_file -> $BUILD_ABS/module_file$CE"
        cp -Rf $module_file $BUILD_ABS/module_file
    fi
}

# ------------------------------------------------------------------------------
# Extensions
# ------------------------------------------------------------------------------

create_extension_links() {
    if [[ ! -d "$BUILD_ABS/extensions" ]]; then
        mkdir -p $BUILD_ABS/extensions
    fi

    for arg in "${extensions[@]}"
    do
        if [[ -z "$arg" ]]; then
            continue
        fi

        local path=`cd "$arg"; pwd`
        local name=`basename $path`

        if [[ ! $name == "hypervisor_"* ]]; then
            prefix="$prefix"
        fi

        if [[ ! -L "$BUILD_ABS/extensions/$prefix$name" ]]; then
            echo -e "linking extension: $CB$path -> $BUILD_ABS/extensions/$prefix$name$CE"
            ln -s $path $BUILD_ABS/extensions/$prefix$name
        fi
    done
}

# ------------------------------------------------------------------------------
# Root Makefile
# ------------------------------------------------------------------------------

create_root_makefile() {
    if nt "$HYPER_ABS/Makefile.bf" "$BUILD_ABS/Makefile"; then
        echo -e "generating root makefile: $CB$BUILD_ABS/Makefile$CE"
        local targets=`cd $BUILD_ABS/makefiles; $HYPER_ABS/tools/scripts/makefile_targets.sh`
        rm -Rf $BUILD_ABS/Makefile
        echo -e "default: all" >> $BUILD_ABS/Makefile
        echo -e "Makefile: $HYPER_ABS/Makefile.bf" >> $BUILD_ABS/Makefile
        echo -e "\t@$HYPER_ABS/configure.sh -r --this-is-make" >> $BUILD_ABS/Makefile
        echo -e "$targets:" >> $BUILD_ABS/Makefile
        echo -e "\t@$HYPER_ABS/configure.sh -s --this-is-make" >> $BUILD_ABS/Makefile
        echo -e "\t@\$(MAKE) --no-print-directory -C makefiles \$(MAKECMDGOALS)" >> $BUILD_ABS/Makefile
    fi
}

# ------------------------------------------------------------------------------
# Filter Arguments
# ------------------------------------------------------------------------------

i=0
extensions[$i]=

while [[ $# -ne 0 ]]; do

    if [[ $1 == "-h" ]] || [[ $1 == "--help" ]]; then
        option_help
        exit 0
    fi

    if [[ $1 == "-c" ]] || [[ $1 == "--clean" ]]; then
        if [[ ! -f env.sh ]]; then
            echo "Unable to clean build. 'env.sh' is missing."
            exit 2
        fi

        source env.sh
        option_distclean

        exit 0
    fi

    if [[ $1 == "-u" ]] || [[ $1 == "--update_all" ]]; then
        update="true"
        rebuild_all="true"
    fi

    if [[ $1 == "-s" ]] || [[ $1 == "--update_scripts" ]]; then
        update="true"
        rebuild_scripts="true"
    fi

    if [[ $1 == "-r" ]] || [[ $1 == "--update_makefiles" ]]; then
        update="true"
        rebuild_makefiles="true"
    fi

    if [[ $1 == "--this-is-make" ]]; then
        this_is_make="true"
    fi

    if [[ $1 == "-m" ]] || [[ $1 == "--module_file" ]]; then
        shift

        if [[ ! -f $1 ]]; then
            echo "ERROR: module file does not exist: $1"
            exit 1
        fi

        module_file=`realpath $1`
    fi

    if [[ $1 == "-g" ]] || [[ $1 == "--compiler" ]]; then
        shift
        compiler=$1
    fi

    if [[ $1 == "-e" || $1 == "--extension" ]]; then
        shift

        if [[ ! -d "$1" ]]; then
            echo "ERROR: extension does not exist: $1"
            exit 1
        fi

        extensions[$i]=`realpath $1`
        i=$((i + 1))
    fi

    shift

done

option_run
