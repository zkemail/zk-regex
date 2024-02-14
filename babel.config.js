module.exports = {
  presets: [
    ["@babel/preset-env", { targets: { node: "current" } }],
    ["@babel/preset-react", { runtime: "automatic" }],
    ["jest"],
  ],
  plugins: ["@babel/plugin-transform-modules-commonjs"],
};
