const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");

// Manually resolving credentials or letting SDK load from ~/.aws/credentials
const client = new SecretsManagerClient({ region: "ap-south-1", profile: "globalscholar" });

async function main() {
  try {
    const cmd = new GetSecretValueCommand({ SecretId: "gs-prod-secrets" });
    const response = await client.send(cmd);
    console.log(response.SecretString);
  } catch (err) {
    console.error(err);
  }
}
main();
