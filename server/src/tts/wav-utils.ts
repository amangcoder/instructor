/**
 * Shared WAV header utility for TTS providers.
 * Prepends a standard 44-byte WAV header to raw 16-bit LE, 24 kHz, mono PCM.
 */
export function buildWav(pcm: Buffer): Buffer {
  const dataSize = pcm.length;
  const header = Buffer.alloc(44);

  // RIFF chunk descriptor
  header.write('RIFF', 0, 'ascii');
  header.writeUInt32LE(36 + dataSize, 4);   // ChunkSize
  header.write('WAVE', 8, 'ascii');

  // "fmt " sub-chunk (16 bytes)
  header.write('fmt ', 12, 'ascii');
  header.writeUInt32LE(16, 16);              // Subchunk1Size (PCM = 16)
  header.writeUInt16LE(1, 20);               // AudioFormat  (1 = PCM)
  header.writeUInt16LE(1, 22);               // NumChannels  (mono)
  header.writeUInt32LE(24000, 24);           // SampleRate   (24 kHz)
  header.writeUInt32LE(48000, 28);           // ByteRate = 24000 * 1 * 2
  header.writeUInt16LE(2, 32);               // BlockAlign   = 1 * 2
  header.writeUInt16LE(16, 34);              // BitsPerSample

  // "data" sub-chunk
  header.write('data', 36, 'ascii');
  header.writeUInt32LE(dataSize, 40);        // Subchunk2Size

  return Buffer.concat([header, pcm]);
}
