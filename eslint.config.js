module.exports = {
    "languageOptions": {
        "globals":{
            "document": "true",
            "window": "true",
            "console": "true",
        },
    extends: 'eslint:recommended',
    parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module'
    },
    rules: {
        semi: ['error', 'always'],
        quotes: ['error', 'single']
    }
}
};