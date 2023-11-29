window.BENCHMARK_DATA = {
  "lastUpdate": 1701218060254,
  "repoUrl": "https://github.com/MystenLabs/sui",
  "entries": {
    "Benchmark": [
      {
        "commit": {
          "author": {
            "email": "106119108+gegaowp@users.noreply.github.com",
            "name": "Ge Gao",
            "username": "gegaowp"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "c4ddf994a9d3bc2f7ded57804dc33d3ce302154a",
          "message": "Update indexer README.md (#14886)\n\n## Description \r\n\r\nmigration run -> database reset\r\nadd v2 and reader / writer instructions\r\n\r\n## Test Plan \r\n\r\neyeball\r\n\r\n---\r\nIf your changes are not user-facing and not a breaking change, you can\r\nskip the following section. Otherwise, please indicate what changed, and\r\nthen add to the Release Notes section as highlighted during the release\r\nprocess.\r\n\r\n### Type of Change (Check all that apply)\r\n\r\n- [ ] protocol change\r\n- [ ] user-visible impact\r\n- [ ] breaking change for a client SDKs\r\n- [ ] breaking change for FNs (FN binary must upgrade)\r\n- [ ] breaking change for validators or node operators (must upgrade\r\nbinaries)\r\n- [ ] breaking change for on-chain data layout\r\n- [ ] necessitate either a data wipe or data migration\r\n\r\n### Release notes",
          "timestamp": "2023-11-28T14:35:57-08:00",
          "tree_id": "bffa4e69fdc0211c7e76c3bcb7b91a76eb8b7a3b",
          "url": "https://github.com/MystenLabs/sui/commit/c4ddf994a9d3bc2f7ded57804dc33d3ce302154a"
        },
        "date": 1701211394019,
        "tool": "cargo",
        "benches": [
          {
            "name": "get_checkpoint",
            "value": 393857,
            "range": "± 23495",
            "unit": "ns/iter"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "ashok@mystenlabs.com",
            "name": "Ashok Menon",
            "username": "amnn"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "1b77f32a8c0c946cf7b2fdc26d49ce8e98b87474",
          "message": "[Tool] Package Dump (#15010)\n\n## Description\r\n\r\nTool to extract all move packages by talking directly to an instance of\r\nthe indexer database.\r\n\r\n## Test Plan\r\n\r\nManual:\r\n\r\n```\r\nsui$ cargo run --bin sui-pkg-dump -- --db-url <url> --output-dir <new-output-dir>\r\n```",
          "timestamp": "2023-11-29T00:26:45Z",
          "tree_id": "6139a956fb1db828acab805aed8b275d59c28b9c",
          "url": "https://github.com/MystenLabs/sui/commit/1b77f32a8c0c946cf7b2fdc26d49ce8e98b87474"
        },
        "date": 1701218055605,
        "tool": "cargo",
        "benches": [
          {
            "name": "get_checkpoint",
            "value": 377622,
            "range": "± 24287",
            "unit": "ns/iter"
          }
        ]
      }
    ]
  }
}