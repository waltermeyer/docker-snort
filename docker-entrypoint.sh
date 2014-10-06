#!/bin/sh

# Expects:
#   -e INTERFACE - sniffing interface ON THE HOST
#   -e INSTANCE - the name of the per-interface instance to support multiple configs per interface
#   -e SENSOR_IP - the IP of the HOST
#   -e OPTS - additional options to pass to snort
#   -e HOMENET - to override HOME_NET setting in snort.conf

if [ "$1" = "snort" ]; then
    LOGDIR=/data/$INSTANCE/logs/$HOSTNAME
    [ -d $LOGDIR ] || mkdir -p $LOGDIR

    CONFDIR=/data/$INSTANCE/etc
    CONFIG=$CONFDIR/snort.conf
    RULES=$CONFDIR/rules

    PPDIR=/data/$INSTANCE/pulledpork
    PPCONFIG=$PPDIR/pulledpork.conf

    if [[ $INTERFACE == zc:* ]]; then
        # PF_RING ZeroCopy
        if [ -n "$ZC_LICENSE_DATA" ]; then
            mkdir -p /etc/pf_ring
            echo $ZC_LICENSE_DATA > /etc/pf_ring/$ZC_LICENSE_MAC
        fi

        mkdir /mnt/huge
        mount -t hugetlbfs nodev /mnt/huge
    fi

    mkdir -p /var/lib/pulledpork
    cp /data/rules/* /var/lib/pulledpork
    mkdir -p /opt/snort/lib/snort_dynamicrules
    mkdir -p /opt/snort/rules

    /opt/snort/bin/pulledpork.pl -n -P -v -T \
        -c $PPCONFIG \
        -m $CONFDIR/sid-msg.map \
        -s /opt/snort/lib/snort_dynamicrules \
        -L $RULES/local.rules,$RULES/hd.rules \
        -o $RULES/snort.$HOSTNAME.rules \
        -e $PPDIR/enablesid.conf \
        -i $PPDIR/disablesid.conf \
        -M $PPDIR/modifysid.conf \
        -b $PPDIR/dropsid.conf \
        -h $LOGDIR/pulledpork.log

    rm -rf /var/lib/pulledpork

    [ -z "$HOMENET" ] || OPTS="$OPTS -S HOME_NET=$HOMENET"
    [ -z "$SENSOR_IP" ] || OPTS="$OPTS -S SENSOR_IP=$SENSOR_IP"

    exec /opt/snort/bin/snort -m 027 -d -l $LOGDIR $OPTS -c $CONFIG -i $INTERFACE -S RULES_FILE=snort.$HOSTNAME.rules
fi

exec "$@"
