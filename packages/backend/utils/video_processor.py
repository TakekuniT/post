
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

        # FFmpeg filter: scale logo, overlay logo, add text
        filter_str = (
            "[1:v]scale=150:-1[logo]; "  # Resize logo to 150px wide
            "[0:v][logo]overlay=W-w-20:H-h-60[v_logo]; "  # Overlay logo
            "[v_logo]drawtext=text='UniPost on iOS':fontcolor=white:fontsize=20:x=W-tw-20:y=H-th-20"
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

# class VideoProcessor:
#     @staticmethod
#     def add_unipost_watermark(input_path: str, output_path: str):
#         # Use absolute paths to avoid 'file not found' issues
#         base_dir = Path(__file__).resolve().parents[1]
#         logo_path = str(base_dir / "assets" / "logo.png")
        
#         if not os.path.exists(logo_path):
#             print(f"ERROR: Logo not found at {logo_path}")
#             return input_path

#         # FFmpeg Filter logic:
#         # [1:v]scale=iw*0.15:-1 -> Scales logo to 15% of its original width, keeps aspect ratio
#         # drawtext -> Adds 'UniPost on iOS' in white, size 24, near the bottom right
#         # overlay -> Places the logo 10px from the right and 50px from the bottom (above the text)
        
#         filter_str = (
#             "[1:v]scale=150:-1[logo]; " # Resize logo to 150px wide
#             "[0:v][logo]overlay=W-w-20:H-h-60[v_logo]; " # Overlay logo 20px from right, 60px from bottom
#             "[v_logo]drawtext=text='UniPost on iOS':fontcolor=white:fontsize=20:x=W-tw-20:y=H-th-20" # Text at the very bottom
#         )

#         command = [
#             "ffmpeg", "-y",
#             "-i", input_path,
#             "-i", logo_path,
#             "-filter_complex", filter_str,
#             "-codec:a", "copy",  # Copy audio to save time
#             "-codec:v", "libx264", # Re-encode video to bake in the watermark
#             "-preset", "ultrafast", # Speed up processing
#             output_path
#         ]

#         print("DEBUG: Processing watermark and text...")
#         try:
#             result = subprocess.run(command, check=True, capture_output=True, text=True)
#             return output_path
#         except subprocess.CalledProcessError as e:
#             print(f"FFmpeg Error: {e.stderr}")
#             return input_path
#         # -i: input logo
#         # filter_complex: positions logo 10px from right (W-w-10) and 10px from bottom (H-h-10)
#         command = [
#             "ffmpeg", "-y", 
#             "-i", input_path, 
#             "-i", logo_path,
#             "-filter_complex", "overlay=W-w-10:H-h-10",
#             "-codec:a", "copy", # Keep original audio without re-encoding
#             output_path
#         ]
        
#         try:
#             subprocess.run(command, check=True, capture_output=True)
#             return output_path
#         except subprocess.CalledProcessError as e:
#             print(f"FFmpeg Error: {e.stderr.decode()}")
#             return input_path # Fallback to original if it fails