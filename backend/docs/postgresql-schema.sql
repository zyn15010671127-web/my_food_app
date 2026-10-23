BEGIN;

CREATE TABLE alembic_version (
    version_num VARCHAR(32) NOT NULL,
    CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)
);

-- Running upgrade  -> 7321fdf75d1b

CREATE TABLE foods (
    id SERIAL NOT NULL,
    name VARCHAR(100) NOT NULL,
    aliases JSON NOT NULL,
    calories_kcal FLOAT NOT NULL,
    protein_g FLOAT NOT NULL,
    carbs_g FLOAT NOT NULL,
    fat_g FLOAT NOT NULL,
    gi FLOAT,
    source VARCHAR NOT NULL,
    is_active BOOLEAN NOT NULL,
    PRIMARY KEY (id)
);

CREATE UNIQUE INDEX ix_foods_name ON foods (name);

CREATE TABLE recipes (
    id SERIAL NOT NULL,
    name VARCHAR(100) NOT NULL,
    cuisine VARCHAR NOT NULL,
    tags JSON NOT NULL,
    goals JSON NOT NULL,
    steps JSON NOT NULL,
    calories_kcal FLOAT NOT NULL,
    protein_g FLOAT NOT NULL,
    carbs_g FLOAT NOT NULL,
    fat_g FLOAT NOT NULL,
    is_active BOOLEAN NOT NULL,
    PRIMARY KEY (id)
);

CREATE UNIQUE INDEX ix_recipes_name ON recipes (name);

CREATE TABLE users (
    id SERIAL NOT NULL,
    username VARCHAR(32) NOT NULL,
    password_hash VARCHAR NOT NULL,
    is_admin BOOLEAN NOT NULL,
    token_version INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (id)
);

CREATE UNIQUE INDEX ix_users_username ON users (username);

CREATE TABLE ai_conversations (
    id VARCHAR(32) NOT NULL,
    user_id INTEGER NOT NULL,
    title VARCHAR NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE INDEX ix_ai_conversations_user_id ON ai_conversations (user_id);

CREATE TABLE meal_records (
    id SERIAL NOT NULL,
    user_id INTEGER NOT NULL,
    food_id INTEGER NOT NULL,
    grams FLOAT NOT NULL,
    meal_type VARCHAR(9) NOT NULL,
    record_date DATE NOT NULL,
    food_name VARCHAR NOT NULL,
    calories_kcal FLOAT NOT NULL,
    protein_g FLOAT NOT NULL,
    carbs_g FLOAT NOT NULL,
    fat_g FLOAT NOT NULL,
    source VARCHAR NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY(food_id) REFERENCES foods (id),
    FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE INDEX ix_meal_records_food_id ON meal_records (food_id);

CREATE INDEX ix_meal_records_record_date ON meal_records (record_date);

CREATE INDEX ix_meal_records_user_id ON meal_records (user_id);

CREATE TABLE nutrition_targets (
    id SERIAL NOT NULL,
    user_id INTEGER NOT NULL,
    record_date DATE NOT NULL,
    bmr_kcal FLOAT NOT NULL,
    tdee_kcal FLOAT NOT NULL,
    calories_kcal FLOAT NOT NULL,
    protein_g FLOAT NOT NULL,
    carbs_g FLOAT NOT NULL,
    fat_g FLOAT NOT NULL,
    goal VARCHAR(11) NOT NULL,
    profile_snapshot JSON NOT NULL,
    rule_version VARCHAR NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY(user_id) REFERENCES users (id),
    CONSTRAINT uq_target_user_date UNIQUE (user_id, record_date)
);

CREATE INDEX ix_nutrition_targets_record_date ON nutrition_targets (record_date);

CREATE INDEX ix_nutrition_targets_user_id ON nutrition_targets (user_id);

CREATE TABLE recipe_ingredients (
    id SERIAL NOT NULL,
    recipe_id INTEGER NOT NULL,
    food_id INTEGER NOT NULL,
    grams FLOAT NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY(food_id) REFERENCES foods (id),
    FOREIGN KEY(recipe_id) REFERENCES recipes (id),
    CONSTRAINT uq_recipe_food UNIQUE (recipe_id, food_id)
);

CREATE INDEX ix_recipe_ingredients_recipe_id ON recipe_ingredients (recipe_id);

CREATE TABLE uploaded_images (
    id VARCHAR(32) NOT NULL,
    user_id INTEGER NOT NULL,
    relative_path VARCHAR NOT NULL,
    width INTEGER NOT NULL,
    height INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE INDEX ix_uploaded_images_user_id ON uploaded_images (user_id);

CREATE TABLE user_profiles (
    user_id INTEGER NOT NULL,
    sex VARCHAR(6) NOT NULL,
    age INTEGER NOT NULL,
    height_cm FLOAT NOT NULL,
    weight_kg FLOAT NOT NULL,
    goal VARCHAR(11) NOT NULL,
    activity_level VARCHAR(9) NOT NULL,
    body_fat_percent FLOAT,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (user_id),
    FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE TABLE ai_messages (
    id SERIAL NOT NULL,
    conversation_id VARCHAR NOT NULL,
    role VARCHAR NOT NULL,
    content VARCHAR NOT NULL,
    mode VARCHAR NOT NULL,
    sources JSON NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY(conversation_id) REFERENCES ai_conversations (id)
);

CREATE INDEX ix_ai_messages_conversation_id ON ai_messages (conversation_id);

CREATE TABLE recognitions (
    id VARCHAR(32) NOT NULL,
    user_id INTEGER NOT NULL,
    image_id VARCHAR NOT NULL,
    status VARCHAR NOT NULL,
    mode VARCHAR NOT NULL,
    message VARCHAR NOT NULL,
    dishes JSON NOT NULL,
    confirmed_record_ids JSON NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY(image_id) REFERENCES uploaded_images (id),
    FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE INDEX ix_recognitions_user_id ON recognitions (user_id);

INSERT INTO alembic_version (version_num) VALUES ('7321fdf75d1b') RETURNING alembic_version.version_num;

COMMIT;
