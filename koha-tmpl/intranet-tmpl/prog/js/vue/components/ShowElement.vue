<template>
    <div
        v-if="
            attr.type == 'text' ||
            attr.type == 'textarea' ||
            (attr.type == 'select' && !attr.av_cat) ||
            attr.showElement?.type == 'text'
        "
    >
        <label>{{ attr.label }}:</label>
        <LinkWrapper :linkData="attr.showElement?.link" :resource="resource">
            <span>
                {{
                    attr.showElement?.format
                        ? attr.showElement?.format(
                              attr.showElement.value,
                              resource
                          )
                        : resource[attr.name]
                }}
            </span>
        </LinkWrapper>
    </div>
    <div
        v-else-if="attr.type == 'av' || (attr.type == 'select' && attr.av_cat)"
    >
        <label>{{ attr.label }}:</label>
        <LinkWrapper :linkData="attr.showElement?.link" :resource="resource">
            <span>{{ get_lib_from_av(attr.av_cat, resource[attr.name]) }}</span>
        </LinkWrapper>
    </div>
    <div v-else-if="attr.type == 'boolean'">
        <label>{{ attr.label }}:</label>
        <span v-if="resource[attr.name]">{{ $__("Yes") }}</span>
        <span v-else>{{ $__("No") }}</span>
    </div>
    <div
        v-else-if="
            attr.type == 'relationship' && attr.showElement.type === 'table'
        "
    >
        <template v-if="attr.showElement.hidden(resource)">
            <label>{{ attr.label }}</label>
            <table>
                <thead>
                    <th
                        v-for="column in attr.showElement.columns"
                        :key="column.name + 'head'"
                    >
                        {{ column.name }}
                    </th>
                </thead>
                <tbody>
                    <tr
                        v-for="(row, counter) in resource[
                            attr.showElement.columnData
                        ]"
                        v-bind:key="counter"
                    >
                        <td
                            v-for="dataColumn in attr.showElement.columns"
                            :key="dataColumn.name + 'data'"
                        >
                            <template v-if="dataColumn.format">
                                <LinkWrapper
                                    :linkData="dataColumn.link"
                                    :resource="row"
                                >
                                    {{
                                        dataColumn.format(
                                            row[dataColumn.value]
                                                ? row[dataColumn.value]
                                                : dataColumn.value,
                                            row
                                        )
                                    }}
                                </LinkWrapper>
                            </template>
                            <template v-else-if="dataColumn.av">
                                <LinkWrapper
                                    :linkData="dataColumn.link"
                                    :resource="row"
                                >
                                    {{
                                        get_lib_from_av(
                                            dataColumn.av,
                                            row[dataColumn.value]
                                        )
                                    }}
                                </LinkWrapper>
                            </template>
                            <template v-else>
                                <LinkWrapper
                                    :linkData="dataColumn.link"
                                    :resource="row"
                                >
                                    {{ row[dataColumn.value] }}
                                </LinkWrapper>
                            </template>
                        </td>
                    </tr>
                </tbody>
            </table>
        </template>
    </div>
    <div v-else-if="attr.showElement?.type === 'component'">
        <template v-if="attr.showElement.hidden(resource)">
            <component
                :is="requiredComponent"
                v-bind="requiredProps(true)"
            ></component>
        </template>
    </div>
</template>

<script>
import { inject } from "vue"
import LinkWrapper from "./LinkWrapper.vue"
import BaseElement from "./BaseElement.vue"

export default {
    components: { LinkWrapper },
    extends: BaseElement,
    setup() {
        const AVStore = inject("AVStore")
        const { get_lib_from_av } = AVStore

        return {
            ...BaseElement.setup(),
            get_lib_from_av,
        }
    },
    props: {
        resource: null,
        attr: null,
    },
    computed: {
        requiredComponent() {
            const component = this.identifyAndImportComponent(this.attr, true)
            return component
        },
        selectOptions() {
            if (this.attr.options) {
                return this.attr.options
            }
            return this.options
        },
    },
    name: "ShowElement",
}
</script>
