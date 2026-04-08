/**
 * SyncService — S3 pre-signed URL generation for database backup sync.
 *
 * Migrated from DatabaseService (SQLite/Drizzle) → DynamoDBService
 * for sync metadata storage (lastSyncAt, sizeBytes per user).
 *
 * All sync metadata uses DynamoDB key pattern:
 *   pk = USER#<userId>  sk = SYNC
 */

import {
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { DynamoDBService } from '../dynamodb/dynamodb.service';
import { SyncStatusDto } from './dto/sync-status.dto';

const URL_EXPIRY_SECONDS = 300; // 5 minutes
const DB_OBJECT_KEY = (userId: string) => `backups/${userId}/instructor.db`;

@Injectable()
export class SyncService {
  private readonly logger = new Logger(SyncService.name);
  private readonly s3: S3Client | null;
  private readonly bucket: string | null;

  constructor(private readonly db: DynamoDBService) {
    this.bucket = process.env.AWS_S3_BUCKET ?? null;
    if (this.bucket) {
      this.s3 = new S3Client({
        region: process.env.AWS_REGION ?? 'ap-south-1',
      });
      this.logger.log(`Sync S3 enabled — bucket=${this.bucket}`);
    } else {
      this.s3 = null;
      this.logger.warn('AWS_S3_BUCKET not set — sync endpoints will fail gracefully');
    }
  }

  private ensureS3(): { s3: S3Client; bucket: string } {
    if (!this.s3 || !this.bucket) {
      throw new ServiceUnavailableException(
        'S3 is not configured on this server. Set AWS_S3_BUCKET and AWS_REGION.',
      );
    }
    return { s3: this.s3, bucket: this.bucket };
  }

  /**
   * Returns a pre-signed PUT URL for the user to upload their SQLite backup.
   */
  async getUploadUrl(userId: string): Promise<{ uploadUrl: string; expiresIn: number }> {
    const { s3, bucket } = this.ensureS3();
    const key = DB_OBJECT_KEY(userId);

    const command = new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      ContentType: 'application/octet-stream',
    });

    const uploadUrl = await getSignedUrl(s3, command, {
      expiresIn: URL_EXPIRY_SECONDS,
    });

    this.logger.log(
      `Pre-signed PUT URL generated for userId=${userId}, key=${key}`,
    );

    return { uploadUrl, expiresIn: URL_EXPIRY_SECONDS };
  }

  /**
   * Returns a pre-signed GET URL for the user to download their SQLite backup.
   */
  async getDownloadUrl(userId: string): Promise<{ downloadUrl: string; expiresIn: number }> {
    const { s3, bucket } = this.ensureS3();
    const key = DB_OBJECT_KEY(userId);

    const command = new GetObjectCommand({
      Bucket: bucket,
      Key: key,
      ResponseContentDisposition: 'attachment; filename="instructor.db"',
    });

    const downloadUrl = await getSignedUrl(s3, command, {
      expiresIn: URL_EXPIRY_SECONDS,
    });

    this.logger.log(
      `Pre-signed GET URL generated for userId=${userId}, key=${key}`,
    );

    return { downloadUrl, expiresIn: URL_EXPIRY_SECONDS };
  }

  /**
   * Returns the last sync metadata for the user.
   */
  async getSyncStatus(userId: string): Promise<SyncStatusDto> {
    const record = await this.db.getSyncMetadata(userId);

    if (!record) {
      return { lastSyncAt: null, sizeBytes: null };
    }

    return {
      lastSyncAt: record.lastSyncAt ? record.lastSyncAt.toISOString() : null,
      sizeBytes: record.sizeBytes ?? null,
    };
  }

  /**
   * Updates sync metadata after a successful upload.
   * Called by the Flutter client after confirming the upload succeeded.
   */
  async confirmSync(userId: string, sizeBytes?: number): Promise<void> {
    const now = new Date();
    await this.db.upsertSyncMetadata(userId, now, sizeBytes);

    this.logger.log(
      `Sync confirmed for userId=${userId}, sizeBytes=${sizeBytes ?? 'unknown'}, at=${now.toISOString()}`,
    );
  }
}
