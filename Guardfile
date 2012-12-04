guard :roxy do
  watch(%r|(/test/.*-test\.xqy)|) { |m| m[1] }
  watch(%r|src/((?!test).*\.xqy)|) { |m| "/test/#{m[1].gsub(/\.xqy/, '-test.xqy')}" }
  watch(%r|test/(lib/.*\.xqy)|) { |m| "/test/test/#{m[1].gsub(/\.xqy/, '-test.xqy')}" }
end