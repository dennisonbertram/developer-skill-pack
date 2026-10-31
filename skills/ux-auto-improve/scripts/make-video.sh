#!/usr/bin/env bash
# Render a narrated walkthrough video from a list of scenes.
#
# Usage: make-video.sh scenes.tsv out.mp4
#   scenes.tsv: one scene per line: <media path><TAB><narration sentence(s)>
#   media: .png/.jpg (held for the narration) or .mp4/.webm (freezes on its last frame
#   if the narration is longer than the clip).
#
# Voice: ElevenLabs when ELEVENLABS_API_KEY is set (UX_VOICE_ID picks the voice; the
# default is "Rachel", a natural female voice). Without a key, or if a request fails,
# that scene falls back to macOS `say` (UX_SAY_VOICE, default Samantha) with a warning.
# Requires ffmpeg, ffprobe, jq, bc, curl.
set -euo pipefail
scenes=$1; out=$2
voice=${UX_VOICE_ID:-21m00Tcm4TlvDq8ikWAM}
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
i=0; list=$work/list.txt; : > "$list"
while IFS=$'\t' read -r media text; do
  [ -z "$media" ] && continue
  i=$((i+1)); a=$work/a$i.mp3; v=$work/s$i.mp4
  code=000
  if [ -n "${ELEVENLABS_API_KEY:-}" ]; then
    body=$(jq -n --arg t "$text" '{text:$t, model_id:"eleven_multilingual_v2"}')
    code=$(curl -s -o "$a" -w '%{http_code}' -X POST "https://api.elevenlabs.io/v1/text-to-speech/$voice" \
      -H "xi-api-key: $ELEVENLABS_API_KEY" -H 'Content-Type: application/json' -d "$body" || echo 000)
  fi
  if [ "$code" != 200 ]; then
    echo "scene $i: ElevenLabs unavailable ($code), using say" >&2
    a=$work/a$i.aiff; say -v "${UX_SAY_VOICE:-Samantha}" -r 175 -o "$a" "$text"
  fi
  ad=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$a")
  fit="scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=white,fps=30"
  case "$media" in
    *.png|*.jpg|*.jpeg)
      dur=$(echo "$ad + 0.6" | bc)
      ffmpeg -nostdin -v error -y -loop 1 -t "$dur" -i "$media" -i "$a" -vf "$fit,format=yuv420p" \
        -af apad -t "$dur" -c:v libx264 -c:a aac -ar 48000 "$v" ;;
    *)
      vd=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$media")
      dur=$(echo "if ($ad + 0.6 > $vd) $ad + 0.6 else $vd" | bc)
      ffmpeg -nostdin -v error -y -i "$media" -i "$a" -vf "$fit,tpad=stop_mode=clone:stop_duration=600,format=yuv420p" \
        -af apad -map 0:v -map 1:a -t "$dur" -c:v libx264 -c:a aac -ar 48000 "$v" ;;
  esac
  echo "file '$v'" >> "$list"
done < "$scenes"
ffmpeg -nostdin -v error -y -f concat -safe 0 -i "$list" -c copy "$out"
echo "$out $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out")s"
