SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(36) NOT NULL,
  anonymous_id VARCHAR(64) NULL,
  student_name VARCHAR(100) NULL,
  phone VARCHAR(32) NULL,
  wechat_openid VARCHAR(128) NULL,
  apple_user_id VARCHAR(128) NULL,
  membership_tier VARCHAR(20) NOT NULL DEFAULT 'free',
  membership_expire_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  last_login_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_anonymous_id (anonymous_id),
  UNIQUE KEY uq_users_phone (phone),
  UNIQUE KEY uq_users_wechat_openid (wechat_openid),
  UNIQUE KEY uq_users_apple_user_id (apple_user_id),
  KEY idx_users_membership_tier (membership_tier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS artworks (
  id VARCHAR(36) NOT NULL,
  user_id VARCHAR(36) NOT NULL,
  title VARCHAR(100) NULL,
  description TEXT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'draft',
  cover_upload_id VARCHAR(36) NULL,
  image_url TEXT NULL,
  critique_json JSON NULL,
  generation_json JSON NULL,
  analysis_summary TEXT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  KEY idx_artworks_user_id (user_id),
  KEY idx_artworks_user_created_at (user_id, created_at),
  KEY idx_artworks_status (status),
  KEY idx_artworks_cover_upload_id (cover_upload_id),
  CONSTRAINT fk_artworks_user_id
    FOREIGN KEY (user_id) REFERENCES users (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS uploads (
  id VARCHAR(36) NOT NULL,
  user_id VARCHAR(36) NULL,
  artwork_id VARCHAR(36) NULL,
  kind VARCHAR(30) NOT NULL DEFAULT 'original',
  object_key VARCHAR(255) NOT NULL,
  url TEXT NULL,
  original_name VARCHAR(255) NULL,
  mime_type VARCHAR(50) NOT NULL,
  size_bytes INT NOT NULL DEFAULT 0,
  width INT NULL,
  height INT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_uploads_object_key (object_key),
  KEY idx_uploads_user_id (user_id),
  KEY idx_uploads_artwork_id (artwork_id),
  KEY idx_uploads_kind (kind),
  CONSTRAINT fk_uploads_user_id
    FOREIGN KEY (user_id) REFERENCES users (id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_uploads_artwork_id
    FOREIGN KEY (artwork_id) REFERENCES artworks (id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS membership_orders (
  id VARCHAR(36) NOT NULL,
  order_no VARCHAR(64) NOT NULL,
  user_id VARCHAR(36) NOT NULL,
  plan VARCHAR(30) NOT NULL,
  amount_cents INT NOT NULL,
  currency VARCHAR(10) NOT NULL DEFAULT 'CNY',
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  membership_days INT NOT NULL,
  membership_start_at DATETIME(3) NULL,
  membership_expire_at DATETIME(3) NULL,
  paid_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_membership_orders_order_no (order_no),
  KEY idx_membership_orders_user_created_at (user_id, created_at),
  KEY idx_membership_orders_status (status),
  CONSTRAINT fk_membership_orders_user_id
    FOREIGN KEY (user_id) REFERENCES users (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS payments (
  id VARCHAR(36) NOT NULL,
  order_id VARCHAR(36) NOT NULL,
  order_no VARCHAR(64) NOT NULL,
  provider VARCHAR(30) NOT NULL,
  provider_trade_no VARCHAR(128) NULL,
  amount_cents INT NOT NULL,
  currency VARCHAR(10) NOT NULL DEFAULT 'CNY',
  status VARCHAR(20) NOT NULL,
  raw_payload JSON NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_payments_provider_trade_no (provider, provider_trade_no),
  KEY idx_payments_order_id (order_id),
  KEY idx_payments_order_no (order_no),
  CONSTRAINT fk_payments_order_id
    FOREIGN KEY (order_id) REFERENCES membership_orders (id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ai_jobs (
  id VARCHAR(36) NOT NULL,
  user_id VARCHAR(36) NOT NULL,
  artwork_id VARCHAR(36) NULL,
  type VARCHAR(30) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'queued',
  input_upload_id VARCHAR(36) NULL,
  output_upload_id VARCHAR(36) NULL,
  error_message TEXT NULL,
  started_at DATETIME(3) NULL,
  finished_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_ai_jobs_user_created_at (user_id, created_at),
  KEY idx_ai_jobs_artwork_id (artwork_id),
  KEY idx_ai_jobs_status (status),
  KEY idx_ai_jobs_type (type),
  KEY idx_ai_jobs_input_upload_id (input_upload_id),
  KEY idx_ai_jobs_output_upload_id (output_upload_id),
  CONSTRAINT fk_ai_jobs_user_id
    FOREIGN KEY (user_id) REFERENCES users (id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_ai_jobs_artwork_id
    FOREIGN KEY (artwork_id) REFERENCES artworks (id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_ai_jobs_input_upload_id
    FOREIGN KEY (input_upload_id) REFERENCES uploads (id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_ai_jobs_output_upload_id
    FOREIGN KEY (output_upload_id) REFERENCES uploads (id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

