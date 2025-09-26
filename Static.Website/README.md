# Static portfolio site

This directory contains a static site that showcases AWS and DBA skills with live code snippets pulled from the AWS/FileMaker scripts in this repo.

## Preview locally

```bash
cd site
python3 -m http.server 9000
# Visit http://localhost:9000 in your browser
```

## Customize

- Replace placeholder contact links in `index.html` with your real email, LinkedIn, and GitHub profile.
- Update the resume highlights under the `#resume` section and drop your latest resume PDF into `site/resume.pdf`.
- Adjust the showcased scripts by editing the `<pre><code>` blocks or adding new cards that point to other files.
- Tweak colors, spacing, or typography in `styles.css` to align with your personal branding.

## Deploy

Everything is static, so you can host it on any static host (S3 + CloudFront, GitHub Pages, Netlify, etc.). Upload the contents of the `site` folder and you’re live.
