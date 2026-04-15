import { IsIn, IsNotEmpty, IsString, Matches, MaxLength } from 'class-validator';

/** Query params for GET /api/app-version/check */
export class CheckVersionDto {
  @IsString()
  @IsNotEmpty()
  @IsIn(['ios', 'android'], { message: "platform must be 'ios' or 'android'" })
  platform!: 'ios' | 'android';

  @IsString()
  @IsNotEmpty()
  @MaxLength(32)
  @Matches(/^[0-9A-Za-z.+-]+$/, {
    message: 'version must be a dot-separated version string',
  })
  version!: string;
}
