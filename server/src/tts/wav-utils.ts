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

/**
 * Parses a WAV buffer (or just its leading bytes — at least the RIFF header
 * + "fmt " + "data" chunk descriptors are required) and returns the audio
 * duration in milliseconds. Returns null when the buffer is not a recognisable
 * RIFF/WAVE PCM stream.
 *
 * Handles standard 44-byte PCM headers as well as files where extra chunks
 * (e.g. "LIST", "bext") sit between "fmt " and "data" by walking the chunk
 * list rather than assuming fixed offsets.
 */
export function getWavDurationMs(buffer: Buffer): number | null {
  if (buffer.length < 44) return null;
  if (buffer.toString('ascii', 0, 4) !== 'RIFF') return null;
  if (buffer.toString('ascii', 8, 12) !== 'WAVE') return null;

  let sampleRate = 0;
  let channels = 0;
  let bitsPerSample = 0;
  let dataSize = 0;

  let offset = 12;
  while (offset + 8 <= buffer.length) {
    const chunkId = buffer.toString('ascii', offset, offset + 4);
    const chunkSize = buffer.readUInt32LE(offset + 4);
    const bodyStart = offset + 8;

    if (chunkId === 'fmt ' && bodyStart + 16 <= buffer.length) {
      channels = buffer.readUInt16LE(bodyStart + 2);
      sampleRate = buffer.readUInt32LE(bodyStart + 4);
      bitsPerSample = buffer.readUInt16LE(bodyStart + 14);
    } else if (chunkId === 'data') {
      dataSize = chunkSize;
      break;
    }

    // Chunks are word-aligned: round odd sizes up by one byte.
    offset = bodyStart + chunkSize + (chunkSize % 2);
  }

  if (sampleRate === 0 || channels === 0 || bitsPerSample === 0 || dataSize === 0) {
    return null;
  }

  const bytesPerSecond = (sampleRate * channels * bitsPerSample) / 8;
  if (bytesPerSecond === 0) return null;
  return Math.round((dataSize * 1000) / bytesPerSecond);
}
