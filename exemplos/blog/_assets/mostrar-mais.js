// "Mostrar mais" na página inicial.
//
// O HTML chega com todos os cards visíveis, e o botão escondido: sem JavaScript, quem lê vê
// a lista inteira. O script esconde os cards marcados `post-oculto`, mostra o botão, e a
// cada clique revela o próximo lote. O tamanho do lote vem da grade (`data-por-clique`),
// que é o mesmo número que `construir.jl` usou para decidir quem começa escondido.
document.addEventListener("DOMContentLoaded", function () {
  var botao = document.getElementById("mostrar-mais");
  var grade = document.querySelector(".cards");
  if (!botao || !grade) return;

  var porClique = parseInt(grade.getAttribute("data-por-clique"), 10) || 3;
  var ocultos = Array.prototype.slice.call(grade.querySelectorAll(".post-oculto"));
  if (ocultos.length === 0) return;

  ocultos.forEach(function (card) { card.hidden = true; });
  botao.hidden = false;

  botao.addEventListener("click", function () {
    var lote = ocultos.splice(0, porClique);
    lote.forEach(function (card) { card.hidden = false; });
    // o foco vai para o primeiro card revelado, e não fica num botão que pode sumir
    var link = lote[0] && lote[0].querySelector("a");
    if (link) link.focus();
    if (ocultos.length === 0) botao.parentElement.hidden = true;
  });
});
