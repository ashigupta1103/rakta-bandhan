module.exports = {
  env: {
    es6: true,
    node: true,
  },
  extends: [
    'eslint:recommended',
    'google',
  ],
  rules: {
    'quotes': ['error', 'single'],
    'indent': ['error', 2],
    'max-len': ['warn', { 'code': 120 }],
    'require-jsdoc': 'off',
    'valid-jsdoc': 'off',
    'no-unused-vars': ['warn'],
    'object-curly-spacing': ['error', 'always'],
  },
  parserOptions: {
    ecmaVersion: 2020,
  },
};
