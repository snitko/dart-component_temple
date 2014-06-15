part of component_temple;

/* This class is a confession in deficiency of HTML and the DOM model.
Imagine you have a <table>. You'd like to dynamycally put some child elements into it,
but put them in a specific place. For example:

  <table>
    <tr><th></th></tr>
    -- PUT ROWS HERE --
  </table>

How do you do it? Well, one way is you can use an element like <div> or <span> instead
of the -- PUT ROWS HERE -- marker. Like this:

  <table>
    <tr><th></th></tr>
    <div id="table_rows"></div>
  </table>

But whoops, the problem is, when your browser parses the code and finds that <div>
it thinks "fuck you, you stupid web developer, it's not supposed to be here."
And guess what you end up with? This:

  <div id="table_rows"></div>
  <table>
    <tr><th></th></tr>
  </table>

So what do you do? Well, supposedly you could use something like <tbody> instead of that div.
But, of course, that is hardly a general solution, since there might be other elements with some
other restrictions. Furthermore, a browser might actually render that wrapper element in some
unpredicatable way. This is why we need some wrapper that browser ignores, but in which we can
still put some elements. Comments are almost perfect for this. Check this out:

  <table>
    <tr><th></th></tr>
    <!--Component_children-->
  </table>

Now, what this class does, is it creates two comment nodes out of this one that you put there:

  <table>
    <tr><th></th></tr>
    <!--Component_children--><!--END-OF-Component_children-->
  </table>

...and then it manages to put various element inbetween those two nodes. It looks as if
they are wrapped, but the browser simply ignores the wrapper nodes, because they are comments.
And comments are allowed anywhere. So instances of this class simply represent these virtual
wrappers, or containers.

*/
class DOMVirtualContainer {

  /*********************************************************************************************/
  /*  Static methods */
  /*********************************************************************************************/

  static Node findNodesByName(String regexp_as_str, Node container, { skip_children: null }) {

    var result = [];
    var regexp = new RegExp(r'^' '$regexp_as_str' r'$');

    if(container.childNodes.isEmpty) return result;

    container.childNodes.forEach((n) {

      if(n.nodeType == 8 && regexp.hasMatch(n.nodeValue)) { result.add(n); }

      else if(n.nodeType == 1) {

        /* skip_children List consists of two elements:
        skip_children[0] is the name of the attribute; skip_children[1] is the value of the attribute;
        If the value is not specified, it is assumed it can be anything. And so the purpose of this,
        is that we DO NOT LOOK INSIDE the elements that matche this condition. For example, if
        skip_attributes == ['data-dont-look-inside-me'] then we will ignore all child nodes
        with attributes data-dont-look-inside-me. If skip_attributes == ['data-dont-look-inside-me-if', 'true'],
        then we will only ignore elements like <div data-dont-look-inside-me-if="true"> but not
        <div data-dont-look-inside-me-if="false">.
        */
        if(
          skip_children == null                                                             ||
          (skip_children.length > 1  && n.attributes[skip_children[0]] != skip_children[1]) ||
          (skip_children.length == 1 && n.attributes[skip_children[0]] == null            )
        )
          DOMVirtualContainer.findNodesByName(regexp_as_str, n).forEach((n) => result.add(n));
      }

    });

    return result;
  }


  /*********************************************************************************************/
  /*  Instance variables */
  /*********************************************************************************************/

  Node _opening;
  Node _closing;
  String name  ;

  /*********************************************************************************************/
  /*  Constructors */
  /*********************************************************************************************/

  DOMVirtualContainer(Node node) {
    
    var next_node = node.nextNode;
    _opening      = node;
    while(next_node != null) {
      if(next_node.nodeValue == "END-OF-${node.nodeValue}") {
        _closing = next_node;
        break;
      }
      next_node = next_node.nextNode;
    }

    if(_closing == null) {
      _opening = new DocumentFragment.html("<!--${node.nodeValue}-->").childNodes[0];
      _closing = new DocumentFragment.html("<!--END-OF-${node.nodeValue}-->").childNodes[0];
      node.parent.insertBefore(_opening, node);
      node.parent.insertBefore(_closing, node);
      node.remove();
    }

    this.name = _opening.nodeValue;

  }
  
  factory DOMVirtualContainer.find(String regexp, Element container, { skip_children: null }) {
    var comment_nodes = DOMVirtualContainer.findNodesByName(regexp, container, skip_children: skip_children);
    if(comment_nodes.isEmpty || comment_nodes.first == null) return;
    else                                                     return new DOMVirtualContainer(comment_nodes.first);
  }

  factory DOMVirtualContainer.findAll(String regexp, Element container, { skip_children: null }) {
    var comment_nodes = DOMVirtualContainer.findNodesByName(regexp, container, skip_children: skip_children);
    if(comment_nodes.isEmpty) return [];

    var invisible_containers = [];
    comment_nodes.forEach((n) {
      invisible_containers.add(new DOMVirtualContainer(n));
    });
    return invisible_containers;
  }

  /*********************************************************************************************/
  /*  Getters and setters */
  /*********************************************************************************************/
  get children {
    var _children = [];
    var next_node = _opening.nextNode;
    while (next_node != _closing) {
      _children.add(next_node);
      next_node = next_node.nextNode;
    }
    return _children;
  }

  get text => _opening.nextNode.text;
  set text(v) {
    children.forEach((c) => c.remove());
    append(new Text(v));
  }

  /*********************************************************************************************/
  /*  Public Methods */
  /*********************************************************************************************/

  prepend(Node el) {
    _opening.parent.insertBefore(el, _opening.nextNode);
  }

  append(Node el) {
    _closing.parent.insertBefore(el, _closing);
  }

}
