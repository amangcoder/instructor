const SAMPLE_RATE = 24_000;
const BYTES_PER_SAMPLE = 2;   // 16-bit LE mono
const DEFAULT_MIN_SILENCE_MS = 150;
const SILENCE_THRESHOLD = 2_000;   // amplitude below this counts as silent (out of 32767)

function align2(offset: number): number {
  return offset % BYTES_PER_SAMPLE === 0 ? offset : offset - 1;
}

function splitEvenly(pcm: Buffer, count: number): Buffer[] {
  const size = align2(Math.floor(pcm.length / count));
  const segs: Buffer[] = [];
  for (let i = 0; i < count; i++) {
    const start = i * size;
    const end = i === count - 1 ? pcm.length : (i + 1) * size;
    segs.push(pcm.subarray(start, end));
  }
  return segs;
}

interface SilenceRegion {
  start: number;
  end: number;
  length: number;
}

function findSilenceRegions(pcm: Buffer, minSilenceMs: number): SilenceRegion[] {
  const minSilenceBytes = Math.round((minSilenceMs / 1000) * SAMPLE_RATE) * BYTES_PER_SAMPLE;
  const regions: SilenceRegion[] = [];
  let silenceStart = -1;

  for (let i = 0; i + 1 < pcm.length; i += BYTES_PER_SAMPLE) {
    const silent = Math.abs(pcm.readInt16LE(i)) < SILENCE_THRESHOLD;
    if (silent && silenceStart === -1) {
      silenceStart = i;
    } else if (!silent && silenceStart !== -1) {
      const length = i - silenceStart;
      if (length >= minSilenceBytes) regions.push({ start: silenceStart, end: i, length });
      silenceStart = -1;
    }
  }
  if (silenceStart !== -1) {
    const length = pcm.length - silenceStart;
    if (length >= minSilenceBytes) regions.push({ start: silenceStart, end: pcm.length, length });
  }
  return regions;
}

/**
 * Splits PCM into `count` segments by finding the N-1 longest silence regions
 * and cutting at the midpoint of each. Falls back to even splitting when fewer
 * than N-1 silence windows are detected.
 */
export function splitPcmOnSilence(pcm: Buffer, count: number, minSilenceMs = DEFAULT_MIN_SILENCE_MS): Buffer[] {
  if (count <= 1) return [pcm];

  const regions = findSilenceRegions(pcm, minSilenceMs);
  const needed = count - 1;

  if (regions.length < needed) return splitEvenly(pcm, count);

  const splitPoints = [...regions]
    .sort((a, b) => b.length - a.length)
    .slice(0, needed)
    .sort((a, b) => a.start - b.start)
    .map(r => align2(Math.floor((r.start + r.end) / 2)));

  const segs: Buffer[] = [];
  let prev = 0;
  for (const pt of splitPoints) {
    segs.push(pcm.subarray(prev, pt));
    prev = pt;
  }
  segs.push(pcm.subarray(prev));
  return segs;
}
