AUDIO_FILE=/Users/oberkowitz/Lofticries.mp3
MULTICAST_IP_ADDR=224.1.1.1
AUDIO_UDP_PORT=3000

gst-launch-1.0 filesrc location="$AUDIO_FILE" ! mad ! audioconvert ! audioresample ! alawenc ! \
rtppcmapay ! udpsink host=$MULTICAST_IP_ADDR auto-multicast=true port=$AUDIO_UDP_PORT
