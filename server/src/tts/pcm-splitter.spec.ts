import { splitPcmAtBoundaries, splitPcmOnSilence } from './pcm-splitter';

const SAMPLE_RATE = 24_000;
const BYTES_PER_SAMPLE = 2;

/** Build a synthetic PCM buffer of the given duration by repeating a sample. */
function buildPcm(durationMs: number, fill = 0): Buffer {
  const samples = Math.round((durationMs / 1000) * SAMPLE_RATE);
  const buf = Buffer.alloc(samples * BYTES_PER_SAMPLE);
  if (fill !== 0) {
    for (let i = 0; i + 1 < buf.length; i += BYTES_PER_SAMPLE) {
      buf.writeInt16LE(fill, i);
    }
  }
  return buf;
}

describe('splitPcmAtBoundaries', () => {
  it('returns the whole buffer for a single boundary', () => {
    const pcm = buildPcm(500);
    const segs = splitPcmAtBoundaries(pcm, [{ startMs: 0, endMs: 500 }]);
    expect(segs).toHaveLength(1);
    expect(segs[0].length).toBe(pcm.length);
  });

  it('splits at exact ms offsets', () => {
    // 1000 ms total, two equal halves.
    const pcm = buildPcm(1000);
    const segs = splitPcmAtBoundaries(pcm, [
      { startMs: 0, endMs: 500 },
      { startMs: 500, endMs: 1000 },
    ]);
    expect(segs).toHaveLength(2);
    // Each half should be exactly 500ms = 12000 samples = 24000 bytes.
    expect(segs[0].length).toBe(500 * (SAMPLE_RATE / 1000) * BYTES_PER_SAMPLE);
    // Last segment runs to end of buffer.
    expect(segs[0].length + segs[1].length).toBe(pcm.length);
  });

  it('keeps the trailing audio even when alignment ends short', () => {
    // The aligner can underestimate the final word's end by tens of ms.
    // We always extend the last segment to end-of-buffer.
    const pcm = buildPcm(1000);
    const segs = splitPcmAtBoundaries(pcm, [
      { startMs: 0, endMs: 400 },
      { startMs: 400, endMs: 950 }, // aligner says 950, audio is 1000
    ]);
    expect(segs[0].length + segs[1].length).toBe(pcm.length);
  });

  it('aligns cuts to the 16-bit sample boundary', () => {
    const pcm = buildPcm(200);
    const segs = splitPcmAtBoundaries(pcm, [
      { startMs: 0, endMs: 13 }, // 13ms × 24kHz = 312 samples → 624 bytes (already even)
      { startMs: 13, endMs: 200 },
    ]);
    expect(segs[0].length % BYTES_PER_SAMPLE).toBe(0);
    expect(segs[1].length % BYTES_PER_SAMPLE).toBe(0);
  });

  it('handles non-default sample rate', () => {
    const pcm = Buffer.alloc(16_000 * 2); // 1s at 16kHz
    const segs = splitPcmAtBoundaries(
      pcm,
      [
        { startMs: 0, endMs: 500 },
        { startMs: 500, endMs: 1000 },
      ],
      16_000,
    );
    expect(segs).toHaveLength(2);
    expect(segs[0].length).toBe(8_000 * 2);
    expect(segs[1].length).toBe(8_000 * 2);
  });

  it('throws on empty boundaries', () => {
    expect(() => splitPcmAtBoundaries(buildPcm(100), [])).toThrow();
  });
});

describe('splitPcmOnSilence', () => {
  it('returns the whole buffer when count is 1', () => {
    const pcm = buildPcm(500, 1000);
    const segs = splitPcmOnSilence(pcm, 1);
    expect(segs).toHaveLength(1);
    expect(segs[0].length).toBe(pcm.length);
  });

  it('falls back to even split when no silence is found', () => {
    // Loud signal everywhere — no silence regions.
    const pcm = buildPcm(600, 25_000);
    const segs = splitPcmOnSilence(pcm, 3);
    expect(segs).toHaveLength(3);
    expect(segs.reduce((sum, s) => sum + s.length, 0)).toBe(pcm.length);
  });
});
