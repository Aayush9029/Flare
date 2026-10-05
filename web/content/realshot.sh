#!/bin/zsh
# usage: realshot.sh src.mov start end speed zoom_from zoom_to out.mp4
src=$1; a=$2; b=$3; sp=$4; z0=$5; z1=$6; out=$7
dur=$(python3 -c "print(($b-$a)/$sp)")
ffmpeg -loglevel error -y -i $src -filter_complex "[0:v]fps=30,trim=$a:$b,setpts=(PTS-STARTPTS)/$sp,crop=3600:2025:0:313,scale=3840:2160,zoompan=z='$z0+($z1-$z0)*min(it/$dur\,1)':x='(iw-iw/zoom)*0.985':y='(ih-ih/zoom)*0.99':d=1:s=1920x1080:fps=30,format=yuv420p[v]" -map "[v]" -c:v libx264 -preset medium -crf 18 -an $out
