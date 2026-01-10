{
  "targets": [
    {
      "target_name": "juzbus",
      "sources": [
        "src/addon.cpp",
        "src/client_wrapper.cpp",
        "src/service_wrapper.cpp",
        "src/callback_handler.cpp"
      ],
      "include_dirs": [
        "<!@(node -p \"require('node-addon-api').include\")",
        "../Sources/JuzbusObjCBridge/include"
      ],
      "libraries": [
        "-L<(module_root_dir)/lib",
        "-ljuzbusObjCBridge",
        "-Wl,-rpath,@loader_path/../lib"
      ],
      "cflags!": ["-fno-exceptions"],
      "cflags_cc!": ["-fno-exceptions"],
      "defines": ["NAPI_DISABLE_CPP_EXCEPTIONS"],
      "xcode_settings": {
        "GCC_ENABLE_CPP_EXCEPTIONS": "YES",
        "CLANG_CXX_LIBRARY": "libc++",
        "MACOSX_DEPLOYMENT_TARGET": "13.0",
        "OTHER_CFLAGS": [
          "-std=c++17"
        ]
      },
      "conditions": [
        [
          "OS==\"mac\"",
          {
            "libraries": [
              "-framework Foundation"
            ]
          }
        ]
      ]
    }
  ]
}
