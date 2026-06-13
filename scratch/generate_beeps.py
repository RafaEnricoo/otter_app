import wave
import math
import struct
import os

def generate_beep(filename, frequency, duration, volume=0.5, sample_rate=44100, double_beep=False):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, 'w') as w:
        w.setnchannels(1)  # Mono
        w.setsampwidth(2)  # 16-bit PCM
        w.setframerate(sample_rate)
        
        num_samples = int(sample_rate * duration)
        
        if double_beep:
            # Generate first beep (40% of duration)
            beep1_samples = int(num_samples * 0.4)
            for i in range(beep1_samples):
                t = float(i) / sample_rate
                value = int(volume * 32767.0 * math.sin(2.0 * math.pi * frequency * t))
                w.writeframes(struct.pack('<h', value))
                
            # Silent gap (20% of duration)
            gap_samples = int(num_samples * 0.2)
            for _ in range(gap_samples):
                w.writeframes(struct.pack('<h', 0))
                
            # Generate second beep (40% of duration)
            beep2_samples = num_samples - beep1_samples - gap_samples
            for i in range(beep2_samples):
                t = float(i) / sample_rate
                value = int(volume * 32767.0 * math.sin(2.0 * math.pi * frequency * t))
                w.writeframes(struct.pack('<h', value))
        else:
            # Single beep
            for i in range(num_samples):
                t = float(i) / sample_rate
                # Apply basic linear envelope to avoid clicks
                envelope = 1.0
                fade_out_samples = int(sample_rate * 0.02)
                if i > num_samples - fade_out_samples:
                    envelope = float(num_samples - i) / fade_out_samples
                
                value = int(volume * 32767.0 * math.sin(2.0 * math.pi * frequency * t) * envelope)
                w.writeframes(struct.pack('<h', value))
    print(f"Generated: {filename}")

if __name__ == "__main__":
    generate_beep("d:/Projek/otter_app/assets/sounds/start.wav", frequency=880, duration=0.15, volume=0.4)
    generate_beep("d:/Projek/otter_app/assets/sounds/error.wav", frequency=350, duration=0.35, volume=0.4, double_beep=True)
