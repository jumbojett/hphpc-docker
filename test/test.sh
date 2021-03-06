#!/bin/sh

cd /hphpc/hhvm/hphp

## Test Environment Initialization

# Make some changes to /etc/hosts to placate tests.
# This DOES NOT persist across layers: https://github.com/docker/docker/issues/10324
cp /etc/hosts /tmp/etc-host

# Example.com doesn't serve up a Connection header anymore,
# which TestExtUrl expects. What. The. Hell.
# Note you need to find a host that ignores Host headers
echo "$(python -c 'import socket; print socket.gethostbyname("www.iana.org")') example.com www.example.com" >> /tmp/etc-host

# The test for gethostbynamel in TestExtNetwork expects only one result
# for gethostbyname("localhost"). Placate it.
sed -i -e 's/^.*ip6-localhost.*$/#/' /tmp/etc-host

# The test for gethostbyaddr in TestExtNetwork expects a result of
# gethostbyaddr("127.0.0.1") == "localhost.localdomain"
sed -i -e 's/^127.0.0.1/127.0.0.1 localhost.localdomain/' /tmp/etc-host

# Can't move because of bind mounts
cat /tmp/etc-host > /etc/hosts

# Link /dev/random to /dev/urandom for MCrypt testing
# Note: The /dev/ editing does not persist across layers for docker
rm -rf /dev/random
ln -s /dev/urandom /dev/random

# Start memcached for the duration of the tests
service memcached start

## Run Tests

# see hphp/test/test.cpp and hphp/test/test_all.cpp
# for what these options mean. They are not documented.
# Briefly, the first option is the 'suite'
# The seocnd option is the 'which'
# and the third option is the 'set'
# Note that for convenience, a second way of calling tests
# can be done if the first option is suite::which (think C++ namespace style)
# Test::RunTestsImpl has a particularly confusing dispatch
# for the actual tests to run

# QuickTests -- runs just the tests listed in test_base_fast.inc
# These mostly test the parser
echo "Running QuickTests..."
./test/test '' '' QuickTests quiet
# TestExt -- runs just the tests listed in test_ext.inc
# These test various functions provided by the builtin extensions
echo "Running TestExt..."
# Note, this is basically the same as running the full TestExt set
# Except we remove all of the tests that fail in our strange
# Environment.
cat /hphpc/hhvm/hphp/test/test_ext.inc | \
    grep RUN_TESTSUITE | \
    sed -E s'/RUN_TESTSUITE\((.*)\);$/\1/' | \
    grep -Ev "TestExtMysql|TestExtPdo" | \
    xargs -I{} sh -c "echo {}; ./test/test '{}' '' '' quiet || true"

# TestCodeRun::TestSanity - Verifies that we can compile code.
echo "Running TestCodeRun::TestSanity..."
./test/test TestCodeRun::TestSanity quiet

# Note that if we had called just ./test/test with no args,
# we would have done the entire TestCodeRun suite.
# This is VERY slow and will take hours to run
# Instead we just ran the bare minimum sanity checks
#./test/test TestCodeRun

