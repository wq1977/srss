const String css = """
html {
  font-size:12pt;
  font-weight:400;
}

html, body {
    max-width: 100%;
    overflow-x: hidden;
}

.dark {
  color: #d1d5db;
}

body{
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

h1 {
  font-size:1.3rem;
}

.readed h1 {
  color: gray;
}

h2 {
  font-size:1.2rem;
}

h3 {
  font-size:1.1rem;
}

h4 {
  font-size:1rem;
}

p{
  text-align:justify;
  line-height: 1.7;
}

.description{
  margin-bottom: 0.5em;
    --tw-text-opacity: 1;
    color: rgba(156,163,175,var(--tw-text-opacity));
}

.subtitle{
  font-size: .875rem;
    line-height: 1.25rem;
    --tw-text-opacity: 1;
    color: rgba(209,213,219,var(--tw-text-opacity));
}

img {
  width:100%;
  height:auto;
  margin:0;
  padding:0;
}
""";
