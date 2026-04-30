import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty } from 'class-validator';

export class RequestOtpDto {
  @ApiProperty({
    description: 'Email address to send the OTP to',
    example: 'user@example.com',
    format: 'email',
  })
  @IsEmail({}, { message: 'email must be a valid email address' })
  @IsNotEmpty()
  email!: string;
}
