part of component_temple;

List findSubclasses(name) {

  final ms         = currentMirrorSystem();
  List  subclasses = [];

  ms.libraries.forEach((k,lib) {
    lib.declarations.forEach((k2, c) {
      if(c is ClassMirror && c.superclass != null) {
        final parentClassName = MirrorSystem.getName(c.superclass.simpleName);
        if (parentClassName == name) {
          subclasses.add(c);
        }
      }
    });
  });

  return subclasses;

}

new_instance_of(String class_name, String library) {

  MirrorSystem mirrors = currentMirrorSystem();
  LibraryMirror     lm = mirrors.libraries.values.firstWhere(
    (LibraryMirror lm) => lm.qualifiedName == new Symbol(library)
  );

  ClassMirror cm = lm.declarations[new Symbol(class_name)];

  InstanceMirror im = cm.newInstance(new Symbol(''), []);
  return im.reflectee;

}
