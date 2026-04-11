const { createHash } = require('crypto');
const payload = '{"locale":"en-US","provider":"kokoro","speechRate":"1.0","text":"Hello","voice":"af_heart"}';
console.log(createHash('sha256').update(payload).digest('hex'));
