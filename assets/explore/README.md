# Keşfet editorial covers

Each WebP is a separately generated editorial cover for the matching stable
article ID in `content/articles.json`. Generated with the built-in image_gen
tool; exact prompts are preserved in `content/article-cover-prompts.json`.
The original dimensions are retained; WebP quality 82 reduces download size.

`article_cover_assets.dart` maps article IDs to bundled asset paths.
`Article.coverImageUrl` uses an explicit CMS image URL when present and this
local cover when the CMS field is empty. Article copy and Firestore records
are unchanged. Cards, feed rows and detail screens share `CoverImage`.

When adding an article, add its cover and mapping together. The cover test
checks content coverage, unique paths and Flutter asset bundle inclusion.
