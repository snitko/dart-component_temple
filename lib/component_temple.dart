library component_temple;

// vendor libs
import 'dart:html'   ;
import 'dart:mirrors';
import 'dart:math'   ;

// local libs
import '../observable/observable.dart' as observable;
import '../attributable/attributable.dart';
import '../validatable/validatable.dart';

// parts of the current lib
part   'src/string_case_operations.dart';
part   'src/dom_virtual_container.dart' ;
part   'src/class_dynamic_operations.dart';
part   'template_stack.dart'        ;
part   'template.dart'              ;
part   'component.dart'             ;

assembleComponents(doc) {
  TemplateStack.collect(doc);
  TemplateStack.buildComponents(doc);
}
