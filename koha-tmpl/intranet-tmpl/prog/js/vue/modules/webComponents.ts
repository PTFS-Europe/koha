import { defineCustomElement } from "vue";
import AdminLeftMenu from "../components/WebComponents/AdminLeftMenu.vue";

const adminLeftMenu = defineCustomElement(AdminLeftMenu);
customElements.define("admin-left-menu", adminLeftMenu);
