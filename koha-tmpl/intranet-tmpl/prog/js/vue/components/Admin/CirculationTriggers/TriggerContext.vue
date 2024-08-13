<template>
    <div class="page-section">
        <table>
            <thead>
                <th>
                    {{ $__("Loan period") }}
                </th>
                <th>
                    {{ $__("Unit") }}
                </th>
                <th>
                    {{ $__("Decreased loan period for high holds") }}
                </th>
                <th>
                    {{ $__("Fine amount") }}
                </th>
                <th>
                    {{ $__("Fine charging interval") }}
                </th>
            </thead>
            <tbody>
                <tr>
                    <td>
                        {{ ruleInfo.issuelength }}
                    </td>
                    <td>
                        {{ ruleInfo.lengthunit }}
                    </td>
                    <td>
                        {{ ruleInfo.decreaseloanholds }}
                    </td>
                    <td>
                        {{ ruleInfo.fine }}
                    </td>
                    <td>
                        {{ ruleInfo.chargeperiod }}
                    </td>
                </tr>
            </tbody>
        </table>
    </div>
</template>

<script>
export default {
    props: ["ruleInfo"],
}
</script>

<style></style>
