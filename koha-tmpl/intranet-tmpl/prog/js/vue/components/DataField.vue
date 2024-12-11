<template>
    <li v-if="item.type === 'string'">
        <label>{{ item.label }}:</label>
        <span>
            {{ item.value }}
        </span>
    </li>
    <li v-if="item.type === 'timestamp'">
        <label>{{ item.label }}:</label>
        <span>
            {{ item.value.substring(0, 10) }}
        </span>
    </li>
    <li v-if="item.type === 'enum'">
        <label>{{ item.label }}:</label>
        <span>
            {{ item.options[item.value] }}
        </span>
    </li>
    <li v-if="item.type === 'percentage'">
        <label>{{ item.label }}:</label>
        <span> {{ parseFloat(item.value) * 100 }}% </span>
    </li>
    <li v-if="item.type === 'number'">
        <label>{{ item.label }}:</label>
        <span>
            {{ parseFloat(item.value).toFixed(2) }}
        </span>
    </li>
    <li v-if="item.type === 'owner'">
        <label>{{ item.label }}:</label>
        <span>
            {{ `${item.value.firstname || ""} ${item.value.surname || ""}` }}
        </span>
    </li>
    <li v-if="item.type === 'creator'">
        <label>{{ item.label }}:</label>
        <span>
            {{ `${item.value.firstname || ""} ${item.value.surname || ""}` }}
        </span>
    </li>
    <li v-if="item.type === 'table'">
        <label>{{ item.label }}:</label>
        <table>
            <thead>
                <th>{{ item.columns[0] }}</th>
                <th>{{ item.columns[1] }}</th>
            </thead>
            <tr v-for="(arrayItem, key) in item.value" v-bind:key="key">
                <td>{{ arrayItem[item.keys[0]] }}</td>
                <td>{{ arrayItem[item.keys[1]] }}</td>
            </tr>
        </table>
    </li>
    <li v-if="item.type === 'link'">
        <label>{{ item.label }}:</label>
        <a :href="item.href">{{ item.linkText }}</a>
    </li>
</template>

<script>
export default {
    props: {
        item: Object,
    },
    data() {
        return {}
    },
}
</script>

<style scoped>
fieldset.rows label {
    width: 15em;
}
</style>
