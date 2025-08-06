document.addEventListener("DOMContentLoaded", function () {
  const notification = document.createElement("div");
  notification.innerText = "🔥 Overthrone Beta Sürümü Yayında!";
  notification.style.position = "fixed";
  notification.style.bottom = "20px";
  notification.style.right = "20px";
  notification.style.backgroundColor = "#222";
  notification.style.color = "white";
  notification.style.padding = "10px 15px";
  notification.style.borderRadius = "10px";
  notification.style.boxShadow = "0 0 10px #000";
  document.body.appendChild(notification);
  setTimeout(() => notification.remove(), 8000);
});