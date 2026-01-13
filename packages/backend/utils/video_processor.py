
import subprocess
import os
from pathlib import Path

class VideoProcessor:
    @staticmethod
    def add_unipost_watermark(input_path: str, output_path: str):
        # Absolute path to logo
        base_dir = Path(__file__).resolve().parents[1]
        logo_path = str(base_dir / "assets" / "logo.png")
        
        if not os.path.exists(logo_path):
            print(f"ERROR: Logo not found at {logo_path}")
            return input_path
        opacity = 0.5
        # FFmpeg filter: scale logo, overlay logo, add text
        # filter_str = (
        #     "[1:v]scale=150:-1[logo]; "  # Resize logo to 150px wide
        #     "[0:v][logo]overlay=W-w-20:H-h-60[v_logo]; "  # Overlay logo
        #     "[v_logo]drawtext=text='UniPost on iOS':fontcolor=white:fontsize=20:x=W-tw-20:y=H-th-20"
        # )
        filter_str = (
            f"[1:v]scale=150:-1,format=rgba,colorchannelmixer=aa={opacity}[logo]; "
            "[0:v][logo]overlay=W-w-20:H-h-60[v_logo]; "
            "[v_logo]drawtext=text='UniPost on iOS':fontcolor=white@0.5:fontsize=20:x=W-tw-20:y=H-th-20"
        )

        command = [
            "ffmpeg", "-y",
            "-i", input_path,
            "-i", logo_path,
            "-filter_complex", filter_str,
            "-c:a", "copy",  # Copy audio (no re-encode)
            "-c:v", "libx264",  # Encode video
            "-preset", "fast",   # Faster encoding, less compression overhead
            "-crf", "23",        # Constant Rate Factor: controls quality/size (lower = bigger, higher = smaller)
            "-pix_fmt", "yuv420p",  # TikTok-compatible pixel format
            "-movflags", "+faststart",  # Good for streaming
            output_path
        ]

        print("DEBUG: Processing watermark and text with controlled bitrate...")
        try:
            subprocess.run(command, check=True, capture_output=True, text=True)
            print(f"Watermark added: {output_path}")
            return output_path
        except subprocess.CalledProcessError as e:
            print(f"FFmpeg Error: {e.stderr}")
            return input_path  # Fallback to original if something fails
        
    @staticmethod
    def add_photo_watermark(photo_paths: list[str]) -> list[str]:
        base_dir = Path(__file__).resolve().parents[1]
        logo_path = str(base_dir / "assets" / "logo.png")

        if not os.path.exists(logo_path):
            print(f"ERROR: Logo not found at {logo_path}")
            return photo_paths

        opacity = 0.5
        output_paths = []

        for input_path in photo_paths:
            if not os.path.exists(input_path):
                print(f"Skipping missing file: {input_path}")
                output_paths.append(input_path)
                continue

            input_path = str(input_path)
            output_path = input_path.replace(".jpg", "_watermarked.jpg")

            filter_str = (
                f"[1:v]scale=150:-1,format=rgba,colorchannelmixer=aa={opacity}[logo]; "
                "[0:v][logo]overlay=W-w-20:H-h-60[v_logo]; "
                "[v_logo]drawtext=text='UniPost on iOS':"
                "fontcolor=white@0.5:fontsize=20:x=W-tw-20:y=H-th-20"
            )

            command = [
                "ffmpeg", "-y",
                "-i", input_path,
                "-i", logo_path,
                "-filter_complex", filter_str,
                "-frames:v", "1",        # single-frame video
                "-c:v", "libx264",
                "-pix_fmt", "yuv420p",   # social-platform safe
                "-movflags", "+faststart",
                output_path
            ]


            try:
                subprocess.run(command, check=True, capture_output=True, text=True)
                print(f"Watermark added: {output_path}")
                output_paths.append(output_path)
            except subprocess.CalledProcessError as e:
                print(f"FFmpeg Error for {input_path}: {e.stderr}")
                output_paths.append(input_path)

        return output_paths

