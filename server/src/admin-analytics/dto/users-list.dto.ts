/**
 * Admin Users List DTOs
 *
 * GET  /api/admin/users          — paginated, searchable list of users
 * PATCH /api/admin/users/:id/role — update a user's role
 */

import { IsIn, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

export const MIN_PAGE = 1;
export const MIN_PAGE_SIZE = 1;
export const MAX_PAGE_SIZE = 100;
export const DEFAULT_PAGE_SIZE = 25;
export const MAX_SEARCH_LENGTH = 120;

export class ListUsersQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(MIN_PAGE)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(MIN_PAGE_SIZE)
  @Max(MAX_PAGE_SIZE)
  pageSize?: number;

  @IsOptional()
  @IsString()
  search?: string;

  @IsOptional()
  @IsIn(['user', 'admin'])
  role?: 'user' | 'admin';
}

export class UpdateUserRoleDto {
  @IsIn(['user', 'admin'])
  role!: 'user' | 'admin';
}

export interface AdminUserRow {
  id: string;
  email: string;
  name: string | null;
  username: string | null;
  role: 'user' | 'admin';
  /** ISO 8601 timestamp */
  createdAt: string;
  /** Number of plans owned by the user */
  planCount: number;
  /** ISO 8601 timestamp of most recent session completion, or null */
  lastActivityAt: string | null;
}

export interface AdminUsersListResponse {
  users: AdminUserRow[];
  total: number;
  page: number;
  pageSize: number;
}
