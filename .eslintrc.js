module.exports = 
    {
        root: true,
        parser: "@typescript-eslint/parser",
        parserOptions: {
            project: [
                "./packages/**/tsconfig.json"
            ]
        },
        plugins: [
            "@typescript-eslint",
            "prettier"
        ],
        extends: [
            "eslint:recommended",
            "plugin:@typescript-eslint/recommended",
            "plugin:prettier/recommended",
            "prettier"
        ],
        ignorePatterns: [
            "dist",
            "node_modules"
        ],
        rules: {
            "@typescript-eslint/no-non-null-assertion": "off",
            "@typescript-eslint/no-var-requires": "off"
        }
    }