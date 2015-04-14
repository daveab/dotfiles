# ==============================================================================
# Check for sudo.
# ==============================================================================
function check-sudo
{
    if [ "$(whoami)" != "root" ]; then
        echo "You must run this script as root"
        exit 1
    fi
}

# ==============================================================================
# Extract archive information.
# Usage  : ard=( $(extract-archive-info $ar) )
# Example: ard=( $(extract-archive-info $ar) )
#          fn=${ard[1]}
#          ext=${ard[2]}
#          d=${ard[3]}
# ==============================================================================
function extract-archive-info
{
    local ar=$1
    local fn=$(basename $ar)
    local ext=$(echo $fn | awk -F. '{print $NF}')
    local d=${fn%.*tar.$ext}
    echo $ar
    echo $fn
    echo $ext
    echo $d
}

# ==============================================================================
# Extract repository information.
# Usage  : ard=( $(extract-repo-info $repo) )
# Example: ard=( $(extract-repo-info $repo) )
#          fn=${ard[1]}
#          ext=${ard[2]}
#          d=${ard[3]}
# ==============================================================================
function extract-repo-info
{
    local repo=$1
    local base=$(basename $repo)
    local ext=$(echo $base | awk -F. '{print $NF}')
    local d=${base%.$ext}
    echo $repo
    echo $d
}

# ==============================================================================
# Calculate number of CPUs supported by this machine.
# ==============================================================================
function num-cpus
{
    echo `cat /proc/cpuinfo | grep processor | wc -l`
}

# ==============================================================================
# Set up work directory
# ==============================================================================
function setup-work-dir
{
    mkdir -p /tmp/build
    pushd /tmp/build
}

# ==============================================================================
# Download archives
# ==============================================================================
function download-archives
{
    echo "Downloading archives..."

    ARCHIVES=(
        http://heanet.dl.sourceforge.net/project/boost/boost/1.54.0/boost_1_54_0.tar.gz
        http://heanet.dl.sourceforge.net/project/rudiments/rudiments/0.32/rudiments-0.32.tar.gz
        https://www.launchpad.net/libmemcached/1.0/1.0.10/+download/libmemcached-1.0.10.tar.gz
        https://curlpp.googlecode.com/files/curlpp-0.7.3.tar.gz
    )

    for archive in ${ARCHIVES[@]}; do
        echo "Downloading $archive..."
        wget $archive -N

        ard=( $(extract-archive-info $archive) )
        fn=${ard[1]}
        ext=${ard[2]}
        d=${ard[3]}

        echo "Extracting $fn..."
        case "$ext" in
            "bz2")
                tar -jxf $fn
            ;;
            "gz")
                tar -zxf $fn
            ;;
            "tgz")
                tar -xf $fn
            ;;
            "tar")
                tar -xf $fn
            ;;
            *)
                echo "unrecognised package: $d"
            ;;
        esac

        echo "Building $fn..."
        run_config=1     # run configure
        run_bootstrap=0  # run b2
        case "$d" in
            boost*)
                run_config=0
                run_bootstrap=1
                CONF_ARGS=()
            ;;
            rudiments*)
                CONF_ARGS=(--prefix=/usr/local)
            ;;
            libmemcached*)
                CONF_ARGS=(--prefix=/usr/local)
            ;;
            curlpp*)
                CONF_ARGS=(--prefix=/usr/local)
            ;;
            *)
                echo "unrecognised package: $d"
            ;;
        esac

        pushd $d
            if (( $run_config )); then
                ./configure ${CONF_ARGS[@]}
                make -j$(num-cpus)
                make install
            fi
            if (( $run_bootstrap )); then
                ./bootstrap.sh ${CONF_ARGS[@]}
                ./b2 -j$(num-cpus)
                ./b2 install
            fi
        popd
    done
}

# =================================================================================
# 3rd party libs
# =================================================================================
function install-third-party
{
    REPOSITORIES=(
        git://github.com/apache/zookeeper.git
        git://github.com/datasift/zeromq3-x.git
        git://github.com/datasift/zmqpp.git
        git://github.com/redis/hiredis.git
        git://github.com/datasift/kafka.git
        git://github.com/ansible/ansible.git
    )

    for repo in ${REPOSITORIES[@]}; do
        info=( $(extract-repo-info $repo) )
        d=${info[1]}

        if [ ! -d "$d" ]; then
            echo "Cloning $repo"
            git clone $repo
        fi
    
        echo "Building $d"
        do_zookeeper_build=0
        do_kafka_build=0
        do_autogen=0
        do_configure=1
        do_make=1
    
        case "$d" in
            "zookeeper")
                do_zookeeper_build=1
                CONF_ARGS=(--prefix=/usr/local)
            ;;
            "zeromq3-x")
                do_autogen=1
                CONF_ARGS=(--prefix=/usr/local)
            ;;
            "zmqpp")
                do_configure=0
                CONF_ARGS=(--prefix=/usr/local)
            ;;
            "hiredis")
                do_configure=0
                CONF_ARGS=(--prefix=/usr/local)
            ;;
            "kafka")
                do_kafka_build=1
                CONF_ARGS=(--prefix=/usr/local)
            ;;
            "ansible")
                do_configure=0
                do_make=0
            ;;
            *)
                echo "unrecognised package: $d"
            ;;
        esac
    
        pushd $d
            git pull
            if (( $do_zookeeper_build )); then
                ant compile_jute
                pushd src/c
                    autoreconf -if
            fi
            if (( $do_kafka_build )); then
                pushd clients/cpp
                    ./autoconf.sh
            fi
            if (( $do_autogen )); then
                ./autogen.sh
            fi
            if (( $do_configure )); then
                ./configure ${CONF_ARGS[@]}
            fi
            if (( $do_make )); then
                make -j$(num-cpus)
            fi
            make install
            if (( $do_kafka_build )); then
                popd
            fi
            if (( $do_zookeeper_build )); then
                popd
            fi
        popd
    done

    #
    # RE2
    #
    if [ ! -d re2 ]; then
        echo "Cloning https://re2.googlecode.com/hg"
        hg clone https://re2.googlecode.com/hg re2
    fi
    echo "Building RE2"
    pushd re2
        hg pull -u
        make install -j$(num-cpus)
    popd
    
    #
    # xxhash
    #
    if [ ! -d xxhash ]; then
        echo "Cloning https://xxhash.googlecode.com/svn/trunk xxhash"
        svn checkout https://xxhash.googlecode.com/svn/trunk xxhash
    fi
    echo "Building xxhash"
    pushd xxhash
        svn update --force
        gcc -shared -o libxxhash.so -c -fpic xxhash.c
        install -D libxxhash.so /usr/local/lib/libxxhash.so.1.0.0
        install -D xxhash.h /usr/local/include/xxhash.h
        pushd /usr/local/lib
            ln -s libxxhash.so.1.0.0 libxxhash.so.1
            ln -s libxxhash.so.1.0.0 libxxhash.so
        popd
    popd
    
    #
    # gperftools
    #
    if [ ! -d gperftools ]; then
        echo "Cloning http://gperftools.googlecode.com/svn/trunk/"
        svn checkout http://gperftools.googlecode.com/svn/trunk/ gperftools
    fi
    echo "Building gperftools"
    pushd gperftools
        svn update --force
        ./autogen.sh
        ./configure --prefix=/usr/local --enable-frame-pointers
        make -j$(num-cpus)
        make install
    popd
}

# ==============================================================================
# Finalize library install / update cache
# ==============================================================================
function finalize-install
{
    ldconfig
    popd
}
