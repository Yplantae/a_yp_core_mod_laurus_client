NOW=$(date '+%y_%m%d_%H%M')
ABSPATH=$(cd "$(dirname "$0")"; pwd -P)

cp -a $ABSPATH/chaos_client_dev $ABSPATH/chaos_client_dev_$NOW
