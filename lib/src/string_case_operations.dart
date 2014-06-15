part of component_temple;

capitalizeFirstLetter(s) {
  return s[0].toUpperCase() + s.substring(1);
}

downcaseFirstLetter(s) {
  return s[0].toLowerCase() + s.substring(1);
}

dashedToCamelcase(str) {
  var result = '';
  str.split('-').forEach((s) {
    result += capitalizeFirstLetter(s);
  });
  return result;
}
