#!/bin/zsh
# builds /tmp/flare-gen/film/flare-film.mp4 from shot list
cd /tmp/flare-gen
V=vid; F=film
react=$V/f-react.mp4; [ -f $react ] || react=$V/f-react2.mp4
iso=$V/s-iso.mp4
norm="scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,fps=30,format=yuv420p,setsar=1"
grade="curves=r='0/0.03 0.5/0.52 1/0.97':g='0/0.02 0.5/0.5 1/0.96':b='0/0.05 0.5/0.47 1/0.92',eq=saturation=0.9,vignette=PI/5,noise=alls=7:allf=t"
shot() {
  local vf="$norm"
  [[ $1 == $V/* ]] && vf="$norm,$grade"
  ffmpeg -loglevel error -y -ss $2 -t $3 -i $1 -vf "$vf" -an -c:v libx264 -preset medium -crf 17 $F/s$4.mp4
}
shot $V/gv2-wide.mp4 0.3 2.6 01
shot $V/gv2-face.mp4 1.0 2.2 02
shot $V/kv4.mp4 2.2 2.6 03
ffmpeg -loglevel error -y -i $F/r-open.mp4 -loop 1 -i endcard/keys.png -filter_complex "[1]format=rgba,fade=in:st=0.2:d=0.12:alpha=1,fade=out:st=1.6:d=0.2:alpha=1[k];[0][k]overlay=shortest=1:enable='between(t,0.2,1.8)',$norm" -an -c:v libx264 -preset medium -crf 17 $F/s04.mp4
shot $F/r-answer.mp4 0.4 2.4 05
shot $V/gv2-ots.mp4 0.5 2.4 06
shot $F/r-risotto.mp4 0.2 2.4 07
shot $F/r-image.mp4 0.4 2.6 08
shot $V/gv2-smile.mp4 0.8 3.2 09
ffmpeg -loglevel error -y -loop 1 -t 3.6 -i endcard/card.png -vf "scale=3840:2160,zoompan=z='1.06-0.06*on/108':x='iw/2-iw/zoom/2':y='ih/2-ih/zoom/2':d=1:s=1920x1080:fps=30,fade=in:st=0:d=0.35,format=yuv420p,setsar=1" -c:v libx264 -preset medium -crf 17 $F/s11.mp4
ls $F/s*.mp4 | sed 's/^/file /;s/file film\//file /' > $F/list.txt
ffmpeg -loglevel error -y -f concat -safe 0 -i $F/list.txt -c copy $F/video.mp4
dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 $F/video.mp4)
ffmpeg -loglevel error -y -i $F/video.mp4 -i $F/m-piano.mp3 -filter_complex "[1:a]apad,atrim=0:$dur,afade=t=in:d=0.3,afade=t=out:st=$(python3 -c "print($dur-1.6)"):d=1.6,volume=0.9[a]" -map 0:v -map "[a]" -c:v libx264 -preset slow -crf 22 -c:a aac -b:a 160k -movflags +faststart -shortest $F/flare-film.mp4
echo "film $(ffprobe -v error -show_entries format=duration -of csv=p=0 $F/flare-film.mp4)s"
